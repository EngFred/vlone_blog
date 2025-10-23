import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';

/// Reusable utility function to crop an image file.
/// If [lockSquare] is true, the cropper will be locked to a 1:1 (square) aspect ratio.
/// Returns the cropped [File] on success, or `null` if the user cancels or cropping fails.
Future<File?> cropImageFile(
  BuildContext context,
  File imageFile, {
  bool lockSquare = false,
}) async {
  final theme = Theme.of(context);

  try {
    final uiSettings = <PlatformUiSettings>[
      AndroidUiSettings(
        toolbarTitle: 'Crop Image',
        toolbarColor: theme.colorScheme.surface,
        toolbarWidgetColor: theme.colorScheme.onSurface,
        activeControlsWidgetColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.background,
        // When lockSquare is true, start with square and lock the ratio.
        initAspectRatio: lockSquare
            ? CropAspectRatioPreset.square
            : CropAspectRatioPreset.original,
        lockAspectRatio: lockSquare,
      ),
      IOSUiSettings(
        title: 'Crop Image',
        doneButtonTitle: 'Done',
        cancelButtonTitle: 'Cancel',
        aspectRatioLockEnabled: lockSquare,
        // iOS doesn't have preset enum, but aspectRatioLockEnabled=true enforces it.
      ),
    ];

    final cropped = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: uiSettings,
      aspectRatio: lockSquare
          ? const CropAspectRatio(ratioX: 1, ratioY: 1)
          : null,
    );

    if (cropped != null) {
      return File(cropped.path);
    }
    return null; // User cancelled
  } catch (e) {
    debugPrint('Error cropping image: $e');
    if (context.mounted) {
      SnackbarUtils.showError(
        context,
        'Failed to crop image. Please try again.',
      );
    }
    return null;
  }
}
