import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';

/// A reusable utility function encapsulating the logic for cropping an image file.
///
/// If [lockSquare] is set to true, the cropping interface constrains the aspect ratio to 1:1.
/// The function returns the resulting cropped [File] on successful completion,
/// or `null` if the user cancels the operation or if the cropping process encounters a failure.
Future<File?> cropImageFile(
  BuildContext context,
  File imageFile, {
  bool lockSquare = false,
}) async {
  final theme = Theme.of(context);

  try {
    // Defining the platform-specific UI settings for the image cropper.
    final uiSettings = <PlatformUiSettings>[
      AndroidUiSettings(
        toolbarTitle: 'Crop Image',
        toolbarColor: theme.colorScheme.surface,
        toolbarWidgetColor: theme.colorScheme.onSurface,
        activeControlsWidgetColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        // Initializes the cropper to a square ratio if locked, otherwise uses the original image ratio.
        initAspectRatio: lockSquare
            ? CropAspectRatioPreset.square
            : CropAspectRatioPreset.original,
        lockAspectRatio: lockSquare,
      ),
      IOSUiSettings(
        title: 'Crop Image',
        doneButtonTitle: 'Done',
        cancelButtonTitle: 'Cancel',
        // Controls whether the aspect ratio can be changed by the user.
        aspectRatioLockEnabled: lockSquare,
      ),
    ];

    // Launching the image cropper with the defined settings.
    final cropped = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: uiSettings,
      // Explicitly setting a 1:1 ratio if square lock is active.
      aspectRatio: lockSquare
          ? const CropAspectRatio(ratioX: 1, ratioY: 1)
          : null,
    );

    if (cropped != null) {
      // Returning the newly created cropped file.
      return File(cropped.path);
    }
    // Returning null indicates the user cancelled the cropping operation.
    return null;
  } catch (e) {
    debugPrint('Error cropping image: $e');
    // Displaying a user-facing error message if the cropping fails.
    if (context.mounted) {
      SnackbarUtils.showError(
        context,
        'Failed to crop image. Please try again.',
      );
    }
    return null;
  }
}
