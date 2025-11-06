import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';

// Enum representing the outcome of a download attempt, used for clear feedback.
enum DownloadResultStatus {
  success,
  failure,
  permissionDenied,
  permissionPermanentlyDenied,
}

/// A wrapper class for the download operation result.
class DownloadResult {
  final DownloadResultStatus status;
  final String? message;

  DownloadResult(this.status, {this.message});
}

/// A robust service for handling the download of media (images/videos)
/// from a URL and saving the file directly to the device's gallery.
class MediaDownloadService {
  MediaDownloadService();

  // Internal instances of network and device information tools.
  final Dio _dio = Dio();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Downloads media from a [url] and saves it to the device's gallery.
  ///
  /// The [mediaType] ('video' or other for image) is crucial for correct
  /// permission handling on modern Android versions and determining the file extension.
  /// Returns a [DownloadResult] object indicating the status of the operation.
  Future<DownloadResult> downloadAndSaveMedia(
    String url,
    String mediaType, {
    Function(int, int)? onReceiveProgress,
  }) async {
    try {
      // 1. Checking and requesting necessary permissions.
      final permissionStatus = await _requestPermission(mediaType);

      if (permissionStatus.isPermanentlyDenied) {
        return DownloadResult(DownloadResultStatus.permissionPermanentlyDenied);
      }
      if (!permissionStatus.isGranted) {
        return DownloadResult(DownloadResultStatus.permissionDenied);
      }

      // 2. Determining a secure, unique temporary file path for the download.
      final tempDir = await getTemporaryDirectory();
      final fileExtension = mediaType == 'video' ? 'mp4' : 'jpg';
      final fileName =
          'media_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final tempPath = '${tempDir.path}/$fileName';

      // 3. Downloading the file content to the temporary path using Dio.
      await _dio.download(url, tempPath, onReceiveProgress: onReceiveProgress);

      // 4. Saving the file from the temporary location to the public gallery.
      final result = await ImageGallerySaverPlus.saveFile(
        tempPath,
        name: fileName,
      );

      // 5. Cleaning up the temporary file after the save operation is complete.
      try {
        await File(tempPath).delete();
      } catch (e) {
        // Logging the cleanup failure, but not failing the entire download operation.
        AppLogger.info('Failed to delete temp file: $e');
      }

      // Interpreting the gallery save result.
      if (result != null && result['isSuccess'] == true) {
        return DownloadResult(DownloadResultStatus.success);
      } else {
        return DownloadResult(
          DownloadResultStatus.failure,
          message: 'Failed to save to gallery.',
        );
      }
    } catch (e) {
      AppLogger.error('Media download failed', error: e);
      return DownloadResult(
        DownloadResultStatus.failure,
        message: e.toString(),
      );
    }
  }

  /// Handles platform-specific permission requests, significantly improving
  /// compatibility with modern Android versions.
  Future<PermissionStatus> _requestPermission(String mediaType) async {
    if (Platform.isIOS) {
      // iOS: A single Photos access permission covers both images and videos.
      return await Permission.photos.request();
    }

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ requires granular permissions based on media type.
        if (mediaType == 'video') {
          return await Permission.videos.request();
        } else {
          return await Permission.photos.request();
        }
      } else if (sdkInt <= 28) {
        // Android 9 and below require the legacy Storage permission.
        return await Permission.storage.request();
      } else {
        // Android 10, 11, 12: No runtime permission is required for saving to
        // standard gallery locations via MediaStore API.
        return PermissionStatus.granted;
      }
    }

    // Default status for other unhandled platforms.
    return PermissionStatus.granted;
  }
}
