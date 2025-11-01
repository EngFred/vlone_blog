import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';

// Enum to represent the download result for clear feedback
enum DownloadResultStatus {
  success,
  failure,
  permissionDenied,
  permissionPermanentlyDenied,
}

class DownloadResult {
  final DownloadResultStatus status;
  final String? message;

  DownloadResult(this.status, {this.message});
}

/// A robust service for handling media downloads and saving to the gallery.
class MediaDownloadService {
  MediaDownloadService();

  // Dio() and DeviceInfoPlugin() are NOT compile-time constants.
  final Dio _dio = Dio();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Downloads media from a URL and saves it to the device's gallery.
  ///
  /// Returns a [DownloadResult] indicating the outcome.
  Future<DownloadResult> downloadAndSaveMedia(
    String url,
    String mediaType, {
    Function(int, int)? onReceiveProgress,
  }) async {
    try {
      // 1. Check and request permissions
      // --- MODIFIED: Pass mediaType for granular Android 13+ permissions
      final permissionStatus = await _requestPermission(mediaType);

      if (permissionStatus.isPermanentlyDenied) {
        return DownloadResult(DownloadResultStatus.permissionPermanentlyDenied);
      }
      if (!permissionStatus.isGranted) {
        return DownloadResult(DownloadResultStatus.permissionDenied);
      }

      // 2. Get a temporary file path
      final tempDir = await getTemporaryDirectory();
      final fileExtension = mediaType == 'video' ? 'mp4' : 'jpg';
      // Create a unique file name
      final fileName =
          'media_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final tempPath = '${tempDir.path}/$fileName';

      // 3. Download the file using Dio
      await _dio.download(url, tempPath, onReceiveProgress: onReceiveProgress);

      // 4. Save the file from the temp path to the gallery
      // --- MODIFIED: Using ImageGallerySaverPlus class ---
      final result = await ImageGallerySaverPlus.saveFile(
        tempPath,
        name: fileName,
      );

      // 5. Clean up the temporary file
      try {
        await File(tempPath).delete();
      } catch (e) {
        // Log this, but don't fail the operation if cleanup fails
        AppLogger.info('Failed to delete temp file: $e');
      }

      // The result format is the same, so this logic remains unchanged
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

  /// Greatly improved permission handling for modern Android ---
  /// Handles platform-specific permission requests.
  Future<PermissionStatus> _requestPermission(String mediaType) async {
    if (Platform.isIOS) {
      // iOS: Always request photos access (which includes videos)
      return await Permission.photos.request();
    }

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ requires granular permissions
        if (mediaType == 'video') {
          return await Permission.videos.request();
        } else {
          return await Permission.photos.request();
        }
      } else if (sdkInt <= 28) {
        // Android 9 and below require legacy storage
        return await Permission.storage.request();
      } else {
        // Android 10, 11, 12: No runtime permission needed
        // for saving to standard gallery directories via MediaStore.
        return PermissionStatus.granted;
      }
    }

    // Default for other platforms (if any)
    return PermissionStatus.granted;
  }
}
