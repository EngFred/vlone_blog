import 'dart:async';
import 'dart:io';
// We use 'dart:ui' to decode images efficiently in a non-Flutter context.
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';

/// Helper to get media dimensions (width and height) from a file before upload.
///
/// This utility supports both image and video files by leveraging:
/// - `dart:ui` for image decoding.
/// - `FFprobeKit` (part of FFmpeg) for video metadata extraction.
Future<({int width, int height})?> getMediaDimensions(
  File file,
  String mediaType,
) async {
  if (mediaType == 'image') {
    try {
      // Use dart:ui to decode image bytes safely
      final bytes = await file.readAsBytes();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      final image = await completer.future;
      return (width: image.width, height: image.height);
    } catch (e) {
      // Note: If using pure Dart/non-Flutter environment, this import may fail.
      AppLogger.warning('Failed to get image dimensions via dart:ui: $e');
      return null;
    }
  } else if (mediaType == 'video') {
    try {
      // Use FFprobeKit to extract video stream dimensions.
      final info = await FFprobeKit.getMediaInformation(file.path);
      final streams = info.getMediaInformation()?.getStreams() ?? [];

      // Find the primary video stream
      final videoStream = streams.firstWhere(
        (stream) => stream.getType() == 'video',
        // Throw an exception if no video stream is found to handle it in the catch block
        orElse: () => throw Exception('No video stream found in metadata.'),
      );

      final width = videoStream.getWidth();
      final height = videoStream.getHeight();

      if (width != null && height != null && width > 0 && height > 0) {
        return (width: width, height: height);
      }

      AppLogger.warning(
        'FFprobe returned invalid dimensions for video: $width x $height',
      );
      return null;
    } catch (e) {
      AppLogger.warning('Failed to get video dimensions via FFprobe: $e');
      return null;
    }
  }
  return null;
}
