import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img_lib;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:vlone_blog_app/core/utils/app_logger.dart';

typedef CompressionProgressCallback = void Function(double percent);

/// A utility class managing the compression of image files to reduce their size
/// while maintaining acceptable visual quality.
/// Compression is initiated only if the input file size exceeds a predefined threshold.
class ImageCompressor {
  /// The default maximum size (in bytes) that triggers a compression attempt. Default: 1 MB.
  static const int defaultMaxSizeBytes = 1 * 1024 * 1024;

  /// The default maximum dimension (width or height) used for resizing the image. Default: 1080px.
  static const double defaultMaxDimension = 1080.0;

  /// The default JPEG quality setting (0-100, where higher means better quality/larger file). Default: 85.
  static const int defaultQuality = 85;

  /// Compressing the given image file only if it is larger than the size threshold.
  ///
  /// - The image is resized if any dimension exceeds [maxDimension], while preserving its aspect ratio.
  /// - The final output is encoded to the JPEG format for consistent size reduction.
  /// - `onProgress`: An optional callback for progress updates (0.0 to 100.0). For image operations,
  ///   this is invoked at 0% before processing and 100% after, since the operation is typically very fast.
  /// - The method returns the **compressed** [File] in the temporary directory. If no size reduction
  ///   was achieved, the **original** file is returned.
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
      AppLogger.info('ImageCompressor: skipping compression (below threshold)');
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

      // Calculating the scale factor if resizing is necessary.
      double scale = 1.0;
      if (image.width > maxDimension || image.height > maxDimension) {
        scale = image.width > image.height
            ? maxDimension / image.width
            : maxDimension / image.height;
        AppLogger.info('ImageCompressor: applying scale factor $scale');
      }

      // Resizing the image if the scale factor is less than 1.0.
      if (scale < 1.0) {
        final int newWidth = (image.width * scale).round();
        final int newHeight = (image.height * scale).round();
        image = img_lib.copyResize(image, width: newWidth, height: newHeight);
        AppLogger.info(
          'ImageCompressor: resized to ${image.width}x${image.height}',
        );
      }

      // Encoding the image to JPEG with the specified quality.
      final Uint8List encoded = img_lib.encodeJpg(image, quality: quality);

      // Writing the encoded data to a temporary file.
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

      // Only returning the new file if it is smaller than the original.
      if (outputBytes < inputBytes) {
        return outFile;
      } else {
        // Cleaning up the temporary file and returning the original since no size reduction occurred.
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
