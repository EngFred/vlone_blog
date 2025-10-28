import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';

typedef CompressionProgressCallback = void Function(double percent);

class VideoCompressor {
  /// Minimum bytes to attempt compression. Default: 2 MB.
  static const int defaultMinSizeBytes = 2 * 1024 * 1024;

  /// Default quality
  static const VideoQuality defaultQuality = VideoQuality.MediumQuality;

  /// Keep a reference to the last subscription so we can unsubscribe safely.
  static Subscription? _lastProgressSubscription;

  /// Compress the given file if it is worth compressing.
  ///
  /// - `onProgress`: optional callback receiving progress as 0..100 double.
  /// - Returns the compressed File (in temp dir) or original file if compression
  /// skipped/failed/produced no savings.
  /// - This must run on the main thread (plugin limitation).
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
        'VideoCompressor: input size=${inputBytes} bytes; threshold=$minSizeBytes',
      );

      if (inputBytes <= minSizeBytes) {
        AppLogger.info('VideoCompressor: skip compression (below threshold)');
        return input;
      }

      // Cancel any ongoing compression to avoid bad state
      await VideoCompress.cancelCompression();

      // Unsubscribe any previous subscription to avoid duplicate callbacks
      try {
        _lastProgressSubscription?.unsubscribe();
      } catch (_) {}

      // Subscribe to progress if requested
      Subscription? sub;
      if (onProgress != null) {
        sub = VideoCompress.compressProgress$.subscribe((progress) {
          try {
            // progress is 0..100
            onProgress(progress);
          } catch (e) {
            // swallow user callback errors
          }
        });
        _lastProgressSubscription = sub;
      }

      AppLogger.info('VideoCompressor: starting compression for ${input.path}');
      final MediaInfo? info = await VideoCompress.compressVideo(
        input.path,
        quality: quality,
        deleteOrigin: false,
      );

      // Unsubscribe safely
      try {
        sub?.unsubscribe();
      } catch (_) {}
      if (identical(_lastProgressSubscription, sub))
        _lastProgressSubscription = null;

      if (info == null || info.path == null || info.path!.isEmpty) {
        AppLogger.warning(
          'VideoCompressor: compressVideo returned null or empty path',
        );
        // Ensure the plugin cache is cleared
        try {
          await VideoCompress.deleteAllCache();
        } catch (_) {}
        return input;
      }

      final compressedFile = File(info.path!);
      if (!await compressedFile.exists()) {
        AppLogger.warning(
          'VideoCompressor: compressed file not found at ${info.path}',
        );
        try {
          await VideoCompress.deleteAllCache();
        } catch (_) {}
        return input;
      }

      final int compressedBytes = await compressedFile.length();
      AppLogger.info(
        'VideoCompressor: compressed size=$compressedBytes bytes (orig=$inputBytes)',
      );

      // If compressed file smaller, copy to temp location and return; otherwise cleanup and return original.
      if (compressedBytes < inputBytes) {
        final tempDir = await getTemporaryDirectory();
        final ext = p.extension(compressedFile.path).isNotEmpty
            ? p.extension(compressedFile.path)
            : '.mp4';
        final target = p.join(
          tempDir.path,
          'compressed_${DateTime.now().millisecondsSinceEpoch}$ext',
        );
        final moved = await compressedFile.copy(target);
        AppLogger.info(
          'VideoCompressor: moved compressed file to ${moved.path}',
        );

        // Delete intermediate compressed path if different from moved path
        if (!p.equals(compressedFile.path, moved.path)) {
          try {
            await compressedFile.delete();
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

        // Clear plugin cache
        try {
          await VideoCompress.deleteAllCache();
        } catch (_) {}

        return moved;
      } else {
        // compressed not smaller — cleanup and return original
        try {
          await compressedFile.delete();
        } catch (_) {}
        try {
          await VideoCompress.deleteAllCache();
        } catch (_) {}
        AppLogger.info(
          'VideoCompressor: compressed not smaller; returning original',
        );
        return input;
      }
    } catch (e, st) {
      if (e is MissingPluginException) {
        AppLogger.error('Plugin not implemented: Falling back to original');
      } else {
        AppLogger.error(
          'VideoCompressor: compression failed: $e',
          error: e,
          stackTrace: st,
        );
      }
      // Best-effort cleanup
      try {
        _lastProgressSubscription?.unsubscribe();
      } catch (_) {}
      try {
        await VideoCompress.cancelCompression();
      } catch (_) {}
      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}
      return input;
    }
  }
}
