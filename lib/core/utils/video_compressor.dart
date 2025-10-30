import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';

typedef CompressionProgressCallback = void Function(double percent);

/// A small local enum to represent quality levels (keeps API shape similar
/// to prior implementations).
enum VideoQuality { veryHigh, high, medium, low, veryLow }

class VideoCompressor {
  /// Minimum bytes to attempt compression. Default: 2 MB.
  static const int defaultMinSizeBytes = 2 * 1024 * 1024;

  /// Default quality
  static const VideoQuality defaultQuality = VideoQuality.medium;

  /// Track the last running FFmpeg session id (so we can cancel).
  static int? _lastSessionId;

  /// Keep a reference to the last progress timer/subscription if needed.
  static StreamSubscription<dynamic>? _lastProgressSub;

  /// Map our VideoQuality to an appropriate CRF value (lower CRF => better quality).
  /// These values are a sensible default — tweak if you want different size/quality tradeoffs.
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

  /// Compress the given file if it is worth compressing.
  ///
  /// - `onProgress`: optional callback receiving progress as 0..100 double.
  /// - Returns the compressed File (in temp dir) or original file if compression
  ///   skipped/failed/produced no savings.
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
        AppLogger.info('VideoCompressor: skip compression (below threshold)');
        return input;
      }

      final tempDir = await getTemporaryDirectory();

      // Try to obtain real duration early (from original file). This avoids
      // copying and makes progress computation accurate in the Statistics callback.
      double durationSeconds = 0.0;
      try {
        // getVideoDuration is a project helper (returns seconds as int/double)
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

      // Copy input to stable temp path (workaround for some file access issues).
      // Some platform implementations of FFmpegKit require a local app-dir path
      // we control; copying ensures predictable behavior. We keep the copy step
      // but attempted to read duration above to avoid unnecessary work where possible.
      srcCopyPath = p.join(
        tempDir.path,
        'ff_src_${const Uuid().v4()}${p.extension(input.path)}',
      );
      await input.copy(srcCopyPath);

      // If we didn't have duration from original, try again on copied file.
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

      // Prepare output path
      final outFileName = 'ff_out_${const Uuid().v4()}.mp4';
      outPath = p.join(tempDir.path, outFileName);

      // Determine CRF from quality
      final crf = _crfForQuality(quality);

      // Build ffmpeg command pieces:
      // - re-encode video using libx264 with chosen CRF and a reasonable preset
      // - try to copy audio (fast). If that fails, we'll retry with audio re-encode.
      // - -movflags +faststart helps playback streaming
      // - scaling limit to max height 480 while preserving aspect ratio
      const scaleFilter =
          '-vf scale=-2:480'; // -2:480 means max height 480px, width calculated to preserve aspect ratio

      // Two audio modes: 'copy' (fast) and 'aac' (fallback)
      String buildCommand({required bool audioCopy}) {
        final audioPart = audioCopy ? '-c:a copy' : '-c:a aac -b:a 128k';
        // Use explicit video codec selection
        return '-y -i "$srcCopyPath" -c:v libx264 -preset veryfast -crf $crf $scaleFilter -movflags +faststart $audioPart "$outPath"';
      }

      AppLogger.info('VideoCompressor: will run ffmpeg with CRF=$crf');

      // Progress state
      double lastReported = 0.0;

      // Helper to run ffmpeg and return success/failure.
      Future<bool> runFfmpegWithAudioCopy({required bool audioCopy}) async {
        final completer = Completer<bool>();

        // Reset last session id before launching
        _lastSessionId = null;

        AppLogger.info(
          'VideoCompressor: executing ffmpeg (audioCopy=$audioCopy)',
        );

        // Execute FFmpeg asynchronously with callbacks.
        // We rely on the onComplete callback to resolve the completer.
        FFmpegKit.executeAsync(
          buildCommand(audioCopy: audioCopy),
          (session) async {
            try {
              // store session id if available
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
          // log callback
          (log) {
            // Optional: you can enable this for deeper debugging
            // AppLogger.debug('FFMPEG LOG: ${log.getMessage()}');
          },
          // statistics callback
          (Statistics stats) {
            try {
              // stats.getTime() returns milliseconds of processed input
              final processedMs = stats.getTime(); // may be 0 initially

              if (durationSeconds > 0) {
                final percent = (processedMs / (durationSeconds * 1000)) * 100;
                final clipped = percent.clamp(0.0, 100.0);
                if (onProgress != null &&
                    (clipped - lastReported).abs() >= 0.5) {
                  lastReported = clipped;
                  try {
                    onProgress(clipped);
                  } catch (_) {}
                }
              } else {
                // Heuristic fallback when duration unknown (soft cap at 99.0)
                const heuristicDenom = 30 * 1000; // 30s
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

        // Wait for ffmpeg completion (success/failure)
        return completer.future;
      }

      // 1) Try with audio copy (fast).
      bool success = await runFfmpegWithAudioCopy(audioCopy: true);

      // 2) If failed, try again with audio re-encode (more compatible).
      if (!success) {
        AppLogger.info(
          'VideoCompressor: retrying ffmpeg with audio re-encode (aac)',
        );
        success = await runFfmpegWithAudioCopy(audioCopy: false);
      }

      // Final progress push (100% on success)
      if (onProgress != null && success) {
        try {
          onProgress(100.0);
        } catch (_) {}
      }

      // If output doesn't exist or failed, cleanup and return original
      outFile = File(outPath);
      if (!success || !await outFile.exists()) {
        AppLogger.warning(
          'VideoCompressor: output not created or ffmpeg failed; returning original',
        );
        return input;
      }

      // Compare sizes
      final int compressedBytes = await outFile.length();
      AppLogger.info(
        'VideoCompressor: compressed size=$compressedBytes bytes (orig=$inputBytes)',
      );

      if (compressedBytes < inputBytes) {
        // Move to a guaranteed temporary path we control and return it
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

        // Delete intermediate out file if different
        if (!p.equals(outFile.path, moved.path)) {
          try {
            await outFile.delete();
          } catch (_) {}
        }

        // Optionally delete original if requested and compressed is smaller
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
        // compressed not smaller — cleanup and return original
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
      // Robust cleanup: attempt to remove the copied src and transient outPath if present.
      try {
        if (srcCopyPath != null) {
          final f = File(srcCopyPath);
          if (await f.exists()) await f.delete();
        }
      } catch (e) {
        AppLogger.warning('VideoCompressor: failed to cleanup src copy: $e');
      }
      // outFile may have been moved; avoid deleting the moved location. Only delete the intermediate if still exists and it's not the moved target.
      try {
        if (outPath != null) {
          final f = File(outPath);
          if (await f.exists()) await f.delete();
        }
      } catch (e) {
        // ignore
      }
    }
  }

  /// Cancel any ongoing compression
  static Future<void> cancel() async {
    try {
      // Cancels all running sessions if session id is not available.
      // FFmpegKit supports cancelling all or a specific session; we try to cancel last session id if we have it.
      if (_lastSessionId != null) {
        try {
          await FFmpegKit.cancel(_lastSessionId!);
          AppLogger.info(
            'VideoCompressor: requested FFmpeg cancel for session id=$_lastSessionId',
          );
        } catch (e) {
          // Fallback to global cancel if per-session fails
          await FFmpegKit.cancel();
          AppLogger.info(
            'VideoCompressor: requested FFmpeg global cancel after session-cancel fallback',
          );
        }
      } else {
        await FFmpegKit.cancel();
        AppLogger.info('VideoCompressor: requested FFmpeg global cancel');
      }
    } catch (e) {
      AppLogger.warning('VideoCompressor: cancel failed: $e');
    }
    try {
      await _lastProgressSub?.cancel();
    } catch (_) {}
    _lastProgressSub = null;
    _lastSessionId = null;
  }
}
