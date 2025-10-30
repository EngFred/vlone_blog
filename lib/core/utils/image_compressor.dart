import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img_lib;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:vlone_blog_app/core/utils/app_logger.dart';

typedef CompressionProgressCallback = void Function(double percent);

/// A utility class for compressing images to reduce file size while maintaining acceptable quality.
/// Compression is applied if the input file exceeds the size threshold.
/// Supports JPEG encoding with configurable quality and max dimensions for resizing.
class ImageCompressor {
  /// Default maximum bytes to trigger compression. Default: 1 MB.
  static const int defaultMaxSizeBytes = 1 * 1024 * 1024;

  /// Default maximum dimension (width or height) for resizing. Default: 1080px.
  static const double defaultMaxDimension = 1080.0;

  /// Default JPEG quality (0-100, higher is better). Default: 85.
  static const int defaultQuality = 85;

  /// Compress the given image file if it exceeds the size threshold.
  ///
  /// - Resizes the image if any dimension exceeds [maxDimension] while preserving aspect ratio.
  /// - Encodes to JPEG format for consistent compression.
  /// - `onProgress`: Optional callback for progress updates (0.0 to 100.0). For images,
  ///   this is invoked at 0% before processing and 100% after, as operations are fast.
  /// - Returns the compressed [File] (in temp dir) or the original if no compression was needed/possible.
  static Future<File> compressIfNeeded(
    File input, {
    int maxSizeBytes = defaultMaxSizeBytes,
    double maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
    CompressionProgressCallback? onProgress,
  }) async {
    if (!await input.exists()) {
      AppLogger.warning(
        'ImageCompressor.compressIfNeeded: input file missing: ${input.path}',
      );
      return input;
    }

    final int inputBytes = await input.length();
    AppLogger.info(
      'ImageCompressor: input size=$inputBytes bytes; threshold=$maxSizeBytes',
    );

    if (inputBytes <= maxSizeBytes) {
      AppLogger.info('ImageCompressor: skip compression (below threshold)');
      return input;
    }

    try {
      onProgress?.call(0.0);

      final Uint8List bytes = await input.readAsBytes();
      img_lib.Image? image = img_lib.decodeImage(bytes);
      if (image == null) {
        AppLogger.warning('ImageCompressor: failed to decode image from bytes');
        return input;
      }

      AppLogger.info(
        'ImageCompressor: original dimensions ${image.width}x${image.height}',
      );

      // Calculate scale factor if resizing is needed
      double scale = 1.0;
      if (image.width > maxDimension || image.height > maxDimension) {
        scale = image.width > image.height
            ? maxDimension / image.width
            : maxDimension / image.height;
        AppLogger.info('ImageCompressor: applying scale factor $scale');
      }

      // Resize if scale < 1.0
      if (scale < 1.0) {
        final int newWidth = (image.width * scale).round();
        final int newHeight = (image.height * scale).round();
        image = img_lib.copyResize(image, width: newWidth, height: newHeight);
        AppLogger.info(
          'ImageCompressor: resized to ${image.width}x${image.height}',
        );
      }

      // Encode to JPEG with specified quality
      final Uint8List encoded = img_lib.encodeJpg(image, quality: quality);

      // Write to temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String outName = 'compressed_image_$timestamp.jpg';
      final String outPath = p.join(tempDir.path, outName);
      final File outFile = await File(outPath).writeAsBytes(encoded);

      final int outputBytes = encoded.lengthInBytes;
      final double reductionPercent =
          ((inputBytes - outputBytes) / inputBytes * 100);
      AppLogger.info(
        'ImageCompressor: output size=$outputBytes bytes (reduction: ${reductionPercent.toStringAsFixed(1)}%)',
      );

      // Only return compressed if smaller than original
      if (outputBytes < inputBytes) {
        return outFile;
      } else {
        // Cleanup and return original
        try {
          await outFile.delete();
        } catch (e) {
          AppLogger.warning(
            'ImageCompressor: failed to delete output file: $e',
          );
        }
        AppLogger.info(
          'ImageCompressor: compressed not smaller; returning original',
        );
        return input;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'ImageCompressor: compression failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return input;
    } finally {
      onProgress?.call(100.0);
    }
  }
}
