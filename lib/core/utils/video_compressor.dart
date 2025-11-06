import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/media_utils.dart';

typedef CompressionProgressCallback = void Function(double percent);

/// A small local enum representing video quality levels, keeping the API shape
/// similar to prior implementations.
enum VideoQuality { veryHigh, high, medium, low, veryLow }

class VideoCompressor {
  /// The minimum size (in bytes) of a video file that will trigger a compression attempt. Default: 2 MB.
  static const int defaultMinSizeBytes = 2 * 1024 * 1024;

  /// The default quality setting being used for compression.
  static const VideoQuality defaultQuality = VideoQuality.medium;

  /// Tracking the last running FFmpeg session ID, allowing for cancellation.
  static int? _lastSessionId;

  /// Holding a reference to the last progress timer or subscription if needed.
  static StreamSubscription<dynamic>? _lastProgressSub;

  /// Maps a [VideoQuality] level to an appropriate CRF (Constant Rate Factor) value.
  /// A lower CRF value results in better quality but a larger file size.
  static int _crfForQuality(VideoQuality q) {
    switch (q) {
      case VideoQuality.veryHigh:
        return 18;
      case VideoQuality.high:
        return 21;
      case VideoQuality.medium:
        return 24;
      case VideoQuality.low:
        return 28;
      case VideoQuality.veryLow:
        return 32;
    }
  }

  /// Compressing the given file only if its size exceeds the minimum threshold.
  ///
  /// - `onProgress`: An optional callback receiving the compression progress as a 0..100 double.
  /// - The method returns the **compressed** [File] located in the temporary directory. If compression
  ///   was skipped, failed, or produced no size savings, the **original** file is returned.
  static Future<File> compressIfNeeded(
    File input, {
    int minSizeBytes = defaultMinSizeBytes,
    VideoQuality quality = defaultQuality,
    bool deleteOrigin = false,
    CompressionProgressCallback? onProgress,
  }) async {
    String? srcCopyPath;
    String? outPath;
    File? outFile;
    try {
      if (!await input.exists()) {
        AppLogger.warning(
          'VideoCompressor.compressIfNeeded: input missing: ${input.path}',
        );
        return input;
      }

      final int inputBytes = await input.length();
      AppLogger.info(
        'VideoCompressor: input size=$inputBytes bytes; threshold=$minSizeBytes',
      );

      if (inputBytes <= minSizeBytes) {
        AppLogger.info(
          'VideoCompressor: skipping compression (below threshold)',
        );
        return input;
      }

      final tempDir = await getTemporaryDirectory();

      // Attempting to obtain the real duration early from the original file. This ensures
      // accurate progress computation in the Statistics callback, avoiding unnecessary copying first.
      double durationSeconds = 0.0;
      try {
        // getVideoDuration is a project helper (returns seconds as int/double).
        final d = await getVideoDuration(input);
        if (d > 0) {
          durationSeconds = d.toDouble();
          AppLogger.info(
            'VideoCompressor: determined duration=${durationSeconds}s from original file',
          );
        } else {
          AppLogger.info(
            'VideoCompressor: could not determine duration from original file (will attempt later)',
          );
        }
      } catch (e) {
        AppLogger.warning(
          'VideoCompressor: duration probe failed for original file: $e',
        );
      }

      // Copying the input to a stable temp path (workaround for potential file access issues).
      // This step ensures predictable behavior on all platforms.
      srcCopyPath = p.join(
        tempDir.path,
        'ff_src_${const Uuid().v4()}${p.extension(input.path)}',
      );
      await input.copy(srcCopyPath);

      // If the duration wasn't available from the original file, trying again on the copied file.
      if (durationSeconds <= 0) {
        try {
          final d2 = await getVideoDuration(File(srcCopyPath));
          if (d2 > 0) {
            durationSeconds = d2.toDouble();
            AppLogger.info(
              'VideoCompressor: determined duration=${durationSeconds}s from copied file',
            );
          }
        } catch (e) {
          AppLogger.warning(
            'VideoCompressor: duration probe failed for copied file: $e',
          );
        }
      }

      // Preparing the output path.
      final outFileName = 'ff_out_${const Uuid().v4()}.mp4';
      outPath = p.join(tempDir.path, outFileName);

      // Determining the CRF value based on the chosen quality.
      final crf = _crfForQuality(quality);

      // The FFmpeg scale filter limits the max height to 480px while preserving the aspect ratio.
      const scaleFilter =
          '-vf scale=-2:480'; // -2:480 means max height 480px, width calculated to preserve aspect ratio.

      // Defining two audio modes: 'copy' (fastest) and 'aac' (a more compatible fallback).
      String buildCommand({required bool audioCopy}) {
        final audioPart = audioCopy ? '-c:a copy' : '-c:a aac -b:a 128k';
        // Using explicit video codec selection.
        return '-y -i "$srcCopyPath" -c:v libx264 -preset veryfast -crf $crf $scaleFilter -movflags +faststart $audioPart "$outPath"';
      }

      AppLogger.info('VideoCompressor: will run ffmpeg with CRF=$crf');

      // State variable for progress tracking.
      double lastReported = 0.0;

      // A helper function for running ffmpeg and reporting success/failure.
      Future<bool> runFfmpegWithAudioCopy({required bool audioCopy}) async {
        final completer = Completer<bool>();

        // Resetting the last session ID before launching a new session.
        _lastSessionId = null;

        AppLogger.info(
          'VideoCompressor: executing ffmpeg (audioCopy=$audioCopy)',
        );

        // Executing FFmpeg asynchronously with callbacks.
        // Relying on the onComplete callback to resolve the completer.
        FFmpegKit.executeAsync(
          buildCommand(audioCopy: audioCopy),
          (session) async {
            try {
              // Storing the session ID if available.
              try {
                _lastSessionId = session.getSessionId();
              } catch (_) {
                _lastSessionId = null;
              }

              final returnCode = await session.getReturnCode();
              if (ReturnCode.isSuccess(returnCode)) {
                AppLogger.info(
                  'VideoCompressor: ffmpeg completed successfully (audioCopy=$audioCopy).',
                );
                completer.complete(true);
              } else if (ReturnCode.isCancel(returnCode)) {
                AppLogger.info('VideoCompressor: ffmpeg was cancelled.');
                completer.complete(false);
              } else {
                final failStack = await session.getFailStackTrace();
                AppLogger.error(
                  'VideoCompressor: ffmpeg failed (audioCopy=$audioCopy). $failStack',
                );
                completer.complete(false);
              }
            } catch (e, st) {
              AppLogger.error(
                'VideoCompressor: ffmpeg onComplete callback error: $e',
                error: e,
                stackTrace: st,
              );
              if (!completer.isCompleted) completer.complete(false);
            }
          },
          // Log callback (optional, uncomment for deeper debugging)
          (log) {
            // AppLogger.debug('FFMPEG LOG: ${log.getMessage()}');
          },
          // Statistics callback for progress updates.
          (Statistics stats) {
            try {
              // stats.getTime() returns milliseconds of processed input.
              final processedMs = stats.getTime(); // may be 0 initially.

              if (durationSeconds > 0) {
                final percent = (processedMs / (durationSeconds * 1000)) * 100;
                final clipped = percent.clamp(0.0, 100.0);
                // Reporting progress only if a significant change occurred.
                if (onProgress != null &&
                    (clipped - lastReported).abs() >= 0.5) {
                  lastReported = clipped;
                  try {
                    onProgress(clipped);
                  } catch (_) {}
                }
              } else {
                // Applying a heuristic fallback when the video duration is unknown (soft cap at 99.0).
                const heuristicDenom =
                    30 * 1000; // Assuming ~30s for the heuristic.
                final heuristic = ((processedMs / heuristicDenom) * 100).clamp(
                  0.0,
                  99.0,
                );
                final clipped = heuristic;
                if (onProgress != null &&
                    (clipped - lastReported).abs() >= 1.0) {
                  lastReported = clipped;
                  try {
                    onProgress(clipped);
                  } catch (_) {}
                }
              }
            } catch (e) {
              AppLogger.warning('VideoCompressor: stats callback error: $e');
            }
          },
        );

        // Waiting for FFmpeg completion (success or failure).
        return completer.future;
      }

      // 1) Trying with audio copy (the fastest option).
      bool success = await runFfmpegWithAudioCopy(audioCopy: true);

      // 2) If the first attempt failed, retrying with audio re-encode (more compatible).
      if (!success) {
        AppLogger.info(
          'VideoCompressor: retrying ffmpeg with audio re-encode (aac)',
        );
        success = await runFfmpegWithAudioCopy(audioCopy: false);
      }

      // Pushing the final progress (100% upon success).
      if (onProgress != null && success) {
        try {
          onProgress(100.0);
        } catch (_) {}
      }

      // If the output file doesn't exist or FFmpeg failed, cleaning up and returning the original.
      outFile = File(outPath);
      if (!success || !await outFile.exists()) {
        AppLogger.warning(
          'VideoCompressor: output not created or ffmpeg failed; returning original',
        );
        return input;
      }

      // Comparing the file sizes.
      final int compressedBytes = await outFile.length();
      AppLogger.info(
        'VideoCompressor: compressed size=$compressedBytes bytes (orig=$inputBytes)',
      );

      if (compressedBytes < inputBytes) {
        // Moving the output to a guaranteed temporary path and returning the new File reference.
        final ext = p.extension(outFile.path).isNotEmpty
            ? p.extension(outFile.path)
            : '.mp4';
        final target = p.join(
          tempDir.path,
          'compressed_${DateTime.now().millisecondsSinceEpoch}$ext',
        );
        final moved = await outFile.copy(target);
        AppLogger.info(
          'VideoCompressor: moved compressed file to ${moved.path}',
        );

        // Deleting the intermediate output file if the location is different from the moved target.
        if (!p.equals(outFile.path, moved.path)) {
          try {
            await outFile.delete();
          } catch (_) {}
        }

        // Optionally deleting the original file if requested and the compressed file is smaller.
        if (deleteOrigin) {
          try {
            await input.delete();
            AppLogger.info('VideoCompressor: deleted original file $input');
          } catch (e) {
            AppLogger.warning('VideoCompressor: failed deleting original: $e');
          }
        }

        return moved;
      } else {
        // Since the compressed file was not smaller, cleaning it up and returning the original.
        try {
          if (await outFile.exists()) await outFile.delete();
        } catch (_) {}
        AppLogger.info(
          'VideoCompressor: compressed not smaller; returning original',
        );
        return input;
      }
    } catch (e, st) {
      AppLogger.error(
        'VideoCompressor: compression failed: $e',
        error: e,
        stackTrace: st,
      );
      return input;
    } finally {
      // Robust cleanup: attempting to remove the copied source and transient output path if they still exist.
      try {
        if (srcCopyPath != null) {
          final f = File(srcCopyPath);
          if (await f.exists()) await f.delete();
        }
      } catch (e) {
        AppLogger.warning('VideoCompressor: failed to cleanup src copy: $e');
      }
      // Avoiding the deletion of the moved file. Only deleting the intermediate output file if it still exists.
      try {
        if (outPath != null) {
          final f = File(outPath);
          if (await f.exists()) await f.delete();
        }
      } catch (e) {
        // Ignoring cleanup errors.
      }
    }
  }

  /// Requesting the cancellation of any ongoing FFmpeg compression session.
  static Future<void> cancel() async {
    try {
      // Trying to cancel the last specific session ID if available.
      if (_lastSessionId != null) {
        try {
          await FFmpegKit.cancel(_lastSessionId!);
          AppLogger.info(
            'VideoCompressor: requested FFmpeg cancel for session id=$_lastSessionId',
          );
        } catch (e) {
          // Falling back to a global cancel if the per-session cancel fails.
          await FFmpegKit.cancel();
          AppLogger.info(
            'VideoCompressor: requested FFmpeg global cancel after session-cancel fallback',
          );
        }
      } else {
        // Performing a global cancel if no session ID was tracked.
        await FFmpegKit.cancel();
        AppLogger.info('VideoCompressor: requested FFmpeg global cancel');
      }
    } catch (e) {
      AppLogger.warning('VideoCompressor: cancel failed: $e');
    }
    // Cancelling the progress subscription and clearing references.
    try {
      await _lastProgressSub?.cancel();
    } catch (_) {}
    _lastProgressSub = null;
    _lastSessionId = null;
  }
}
