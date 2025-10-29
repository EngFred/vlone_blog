import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:vlone_blog_app/core/utils/app_logger.dart';

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

      // Copy input to stable temp path (workaround for some file access issues)
      final tempDir = await getTemporaryDirectory();
      final srcCopyPath = p.join(
        tempDir.path,
        'ff_src_${const Uuid().v4()}${p.extension(input.path)}',
      );
      await input.copy(srcCopyPath);

      // Prepare output path
      final outFileName = 'ff_out_${const Uuid().v4()}.mp4';
      final outPath = p.join(tempDir.path, outFileName);

      // Determine CRF from quality
      final crf = _crfForQuality(quality);

      // Build ffmpeg command:
      // - re-encode video using libx264 with chosen CRF and a reasonable preset
      // - keep original audio (copy) to avoid extra quality loss - change if you want
      // - -movflags +faststart helps playback streaming
      // - scale is applied to ensure max height is 480px.
      // 💡 CHANGE HERE: Added the scaling filter
      const scaleFilter =
          ' -vf scale=-2:480 '; // -2:480 means max height 480px, width is calculated to preserve aspect ratio

      final command =
          '-y -i "$srcCopyPath" -vcodec libx264 -preset veryfast -crf $crf ${scaleFilter.trim()} -movflags +faststart -acodec copy "$outPath"';

      AppLogger.info('VideoCompressor: running ffmpeg: $command');

      double lastReported = 0.0;
      double durationSeconds = 0.0;

      // Try to get duration using a project helper if available; otherwise we'll
      // fall back to reading duration from ffmpeg statistics once available.
      try {
        // If your project has a helper like getVideoDuration(File), prefer it:
        // final d = await getVideoDuration(File(srcCopyPath));
        // if (d != null) durationSeconds = d;
        // To avoid dependency on external helper, we leave durationSeconds=0 for now.
      } catch (_) {
        // ignore; duration will be obtained from statistics
      }

      // Subscribe to statistics via the statistics callback to compute progress.
      final completer = Completer<bool>();

      _lastSessionId = null;

      // Execute FFmpeg asynchronously with callbacks
      await FFmpegKit.executeAsync(
            command,
            (session) async {
              final returnCode = await session.getReturnCode();
              if (ReturnCode.isSuccess(returnCode)) {
                AppLogger.info(
                  'VideoCompressor: ffmpeg completed successfully.',
                );
                completer.complete(true);
              } else if (ReturnCode.isCancel(returnCode)) {
                AppLogger.info('VideoCompressor: ffmpeg was cancelled.');
                completer.complete(false);
              } else {
                final failStack = await session.getFailStackTrace();
                AppLogger.error('VideoCompressor: ffmpeg failed. $failStack');
                completer.complete(false);
              }
            },
            (log) {
              // Optional: log ffmpeg stdout/stderr if you want
              // AppLogger.debug('FFMPEG LOG: ${log.getMessage()}');
            },
            (Statistics stats) {
              try {
                // stats.getTime() returns milliseconds of processed input
                final processedMs = stats.getTime(); // may be 0 initially
                // If we don't yet have durationSeconds, stat may include 'duration' via stats.getVideoFrameNumber() etc.
                // Safe approach: if durationSeconds known, compute percent; else update using stats if possible.
                if (durationSeconds <= 0) {
                  // Attempt to use stats to estimate duration if possible (some builds populate other fields)
                  // We can't always get total duration from statistics reliably—so percent may be approximate.
                }

                if (durationSeconds > 0) {
                  final percent =
                      (processedMs / (durationSeconds * 1000)) * 100;
                  final clipped = percent.clamp(0.0, 100.0);
                  // Only call callback if progress changed meaningfully
                  if (onProgress != null &&
                      (clipped - lastReported).abs() >= 0.5) {
                    lastReported = clipped;
                    try {
                      onProgress(clipped);
                    } catch (_) {}
                  }
                } else {
                  // If duration unknown, emit incremental progress heuristic:
                  // Map processedMs to a soft progress number using a rough cap (e.g., assume typical duration 30s)
                  final heuristicDenom = 30 * 1000; // 30s
                  final heuristic = ((processedMs / heuristicDenom) * 100)
                      .clamp(0.0, 99.0);
                  final clipped = heuristic;
                  if (onProgress != null &&
                      (clipped - lastReported).abs() >= 1.0) {
                    lastReported = clipped;
                    try {
                      onProgress(clipped);
                    } catch (_) {}
                  }
                }
              } catch (e, st) {
                // swallow
                AppLogger.warning('VideoCompressor: stats callback error: $e');
              }
            },
          )
          .then((session) {
            // store sessionId so we can cancel later if needed
            try {
              _lastSessionId = session.getSessionId();
            } catch (_) {
              _lastSessionId = null;
            }
          })
          .catchError((e, st) {
            AppLogger.error(
              'VideoCompressor: ffmpeg executeAsync threw: $e',
              error: e,
              stackTrace: st,
            );
          });

      // Wait for completion result
      final success = await completer.future;

      // Final progress report (100% if success)
      if (onProgress != null && success) {
        try {
          onProgress(100.0);
        } catch (_) {}
      }

      // If output doesn't exist or failed, cleanup and return original
      final outFile = File(outPath);
      if (!success || !await outFile.exists()) {
        AppLogger.warning(
          'VideoCompressor: output not created; returning original',
        );
        // cleanup temp src
        try {
          final f = File(srcCopyPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
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

        // Cleanup src copy
        try {
          final f = File(srcCopyPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}

        return moved;
      } else {
        // compressed not smaller — cleanup and return original
        try {
          if (await outFile.exists()) await outFile.delete();
        } catch (_) {}
        try {
          final f = File(srcCopyPath);
          if (await f.exists()) await f.delete();
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
      // Best-effort cleanup
      try {
        final tempDir = await getTemporaryDirectory();
        final files = tempDir.listSync().whereType<File>();
        // no-op fallback cleanup (do not aggressively delete)
      } catch (_) {}
      return input;
    }
  }

  /// Cancel any ongoing compression
  static Future<void> cancel() async {
    try {
      // Cancels all running sessions
      await FFmpegKit.cancel();
      AppLogger.info('VideoCompressor: requested FFmpeg cancel');
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
