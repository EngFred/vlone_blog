// features/posts/presentation/widgets/media_upload_widget.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart'; // Added for showing errors
import 'package:flutter/painting.dart'; // Added for pre-flight checking images

import 'media_picker_sheet.dart';
import 'media_placeholder.dart';
import 'media_preview.dart';
import 'trimmer_view.dart';

class MediaUploadWidget extends StatefulWidget {
  final Function(File?, String?) onMediaSelected;

  const MediaUploadWidget({super.key, required this.onMediaSelected});

  @override
  State<MediaUploadWidget> createState() => _MediaUploadWidgetState();
}

class _MediaUploadWidgetState extends State<MediaUploadWidget> {
  File? _mediaFile;
  String? _mediaType;
  VideoPlayerController? _videoController;
  bool _isPreviewPlaying = false;

  Future<void> _pickMedia(ImageSource source, bool isImage) async {
    final picker = ImagePicker();
    XFile? pickedFile;

    // FIX: Wrap the picking process in try...catch to handle system errors
    try {
      pickedFile = isImage
          ? await picker.pickImage(source: source)
          : await picker.pickVideo(source: source);
    } catch (e) {
      debugPrint('Error picking media: $e');
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Failed to pick media. Please try again.',
        );
      }
      return;
    }

    if (pickedFile == null) return; // User cancelled
    final file = File(pickedFile.path);
    final mediaType = isImage ? 'image' : 'video';

    await _videoController?.dispose();
    _videoController = null;
    setState(() => _isPreviewPlaying = false);

    if (mediaType == 'video') {
      // FIX: Wrap video initialization in a try...catch for cloud files/unsupported formats
      try {
        final duration = await getVideoDuration(file);
        if (duration > Constants.maxVideoDurationSeconds) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video exceeds 10 minutes')),
            );
          }
          return;
        }

        // Initialize controller
        _videoController = VideoPlayerController.file(file);
        // CRITICAL: Await initialization
        await _videoController!.initialize();

        // If initialization succeeds, setup listener and state
        _videoController!.addListener(() {
          if (!_videoController!.value.isPlaying &&
              _videoController!.value.position >=
                  _videoController!.value.duration) {
            setState(() => _isPreviewPlaying = false);
            _videoController!.seekTo(Duration.zero);
          }
        });

        setState(() {
          _mediaFile = file;
          _mediaType = mediaType;
        });
        widget.onMediaSelected(_mediaFile, _mediaType);
      } catch (e) {
        debugPrint('Error initializing video player: $e');
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Failed to load video. It may be in the cloud or in an unsupported format.',
          );
        }
        // Clean up
        await _videoController?.dispose();
        _videoController = null;
      }
    } else {
      // FIX: Also pre-flight the image to check if it's readable
      try {
        final imageBytes = await file.readAsBytes();
        await decodeImageFromList(imageBytes);

        // If successful, set state
        setState(() {
          _mediaFile = file;
          _mediaType = mediaType;
        });
        widget.onMediaSelected(_mediaFile, _mediaType);
      } catch (e) {
        debugPrint('Error loading image: $e');
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Failed to load image. It may be in the cloud or in an unsupported format.',
          );
        }
      }
    }
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => MediaPickerSheet(onPick: _pickMedia),
    );
  }

  void _removeMedia() {
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _mediaFile = null;
      _mediaType = null;
      _isPreviewPlaying = false;
    });
    widget.onMediaSelected(null, null);
  }

  Future<void> _editMedia() async {
    if (_mediaFile == null) return;

    if (_mediaType == 'image') {
      // 1. Get the current app theme from the context.
      final theme = Theme.of(context);

      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: _mediaFile!.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              // Set toolbar to your desired 'surface' color
              toolbarColor: theme.colorScheme.surface,
              // Set toolbar text/icons to 'onSurface' for contrast
              toolbarWidgetColor: theme.colorScheme.onSurface,

              // Keep interactive elements like handles as your 'primary' (accent) color
              activeControlsWidgetColor: theme.colorScheme.primary,
              // Set the cropper background to your app's background color
              backgroundColor: theme.colorScheme.background,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Crop Image',
              doneButtonTitle: 'Done',
              cancelButtonTitle: 'Cancel',
            ),
          ],
        );

        // handle both CroppedFile and XFile (older versions)
        if (cropped != null) {
          final croppedPath = cropped.path;
          setState(() {
            _mediaFile = File(croppedPath);
          });
          widget.onMediaSelected(_mediaFile, _mediaType);
        }
      } catch (e) {
        debugPrint('Error cropping image: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to crop image')));
      }
    } else if (_mediaType == 'video') {
      // Video trimming logic remains the same
      final trimmedFilePath = await Navigator.of(context).push(
        MaterialPageRoute<String?>(
          builder: (context) => TrimmerView(_mediaFile!),
        ),
      );

      if (trimmedFilePath != null) {
        await _videoController?.dispose();
        final newFile = File(trimmedFilePath);
        _videoController = VideoPlayerController.file(newFile)
          ..initialize().then((_) => setState(() {}));

        setState(() {
          _mediaFile = newFile;
          _isPreviewPlaying = false;
        });
        widget.onMediaSelected(_mediaFile, _mediaType);
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _mediaFile == null
        ? MediaPlaceholder(onTap: _showPickOptions)
        : MediaPreview(
            file: _mediaFile!,
            mediaType: _mediaType!,
            videoController: _videoController,
            isPlaying: _isPreviewPlaying,
            onPlayPause: () {
              if (_videoController == null) return;
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                  _isPreviewPlaying = false;
                } else {
                  _videoController!.play();
                  _isPreviewPlaying = true;
                }
              });
            },
            onRemove: _removeMedia,
            onEdit: _editMedia,
          );
  }
}
