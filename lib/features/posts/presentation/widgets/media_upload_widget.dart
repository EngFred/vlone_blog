import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/crop_utils.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart'; // Already there, used for warning

import 'media_picker_sheet.dart';
import 'media_placeholder.dart';
import 'media_preview.dart';
import 'trimmer_view.dart';

class MediaUploadWidget extends StatefulWidget {
  final Function(File?, String?) onMediaSelected;

  /// Optional callback used to notify parent that media processing (duration fetch,
  /// video initialization, trimming flow) is underway. Parent should show a
  /// full-screen overlay when true.
  final void Function(bool isProcessing)? onProcessing;

  const MediaUploadWidget({
    super.key,
    required this.onMediaSelected,
    this.onProcessing,
  });

  @override
  State<MediaUploadWidget> createState() => _MediaUploadWidgetState();
}

class _MediaUploadWidgetState extends State<MediaUploadWidget> {
  File? _mediaFile;
  String? _mediaType;
  VideoPlayerController? _videoController;
  bool _isPreviewPlaying = false;
  // bool _isLoadingMedia = false; // Removed or ignored as per request

  Future<void> _pickMedia(ImageSource source, bool isImage) async {
    final picker = ImagePicker();
    XFile? pickedFile;
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

    // Notify parent that processing is starting (show full-screen overlay)
    widget.onProcessing?.call(true);

    if (mediaType == 'image') {
      // Images: Quick validation and set (no duration check needed)
      try {
        final imageBytes = await file.readAsBytes();
        await decodeImageFromList(imageBytes);
        if (mounted) {
          setState(() {
            _mediaFile = file;
            _mediaType = mediaType;
            _isPreviewPlaying = false;
            // _isLoadingMedia = false; // Removed
          });
        }
        widget.onMediaSelected(file, mediaType);
      } catch (e) {
        debugPrint('Error loading image: $e');
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Failed to load image. It may be in the cloud or in an unsupported format.',
          );
        }
      } finally {
        // Done processing (hide overlay)
        widget.onProcessing?.call(false);
      }
    } else {
      // Videos: Duration check + auto-trim if needed
      try {
        // 1) Fetch duration (overlay should be visible while this is running)
        final duration = await getVideoDuration(file); // Returns int (seconds)
        final double maxAllowed = Constants.maxVideoDurationSeconds
            .toDouble(); // Use your constant
        File finalFile = file;
        bool needsAutoTrim = duration > maxAllowed;

        if (needsAutoTrim) {
          // UX: Warn user, then auto-open trim with 0-maxAllowed preset
          if (mounted) {
            SnackbarUtils.showWarning(
              context,
              'Video is longer than ${Constants.maxVideoDurationSeconds} seconds. Please trim to ${Constants.maxVideoDurationSeconds}s or less.',
            );
          }

          // hide overlay before navigating to trimming screen so trimmed view can appear normally
          widget.onProcessing?.call(false);

          // Auto-nav to trim view, pre-set to 0-maxAllowed (user must save to return a trimmed file)
          final trimmedPath = await Navigator.of(context).push<String?>(
            MaterialPageRoute(
              builder: (context) => TrimmerView(
                file,
                maxDuration: maxAllowed,
                initialStart: 0.0,
                initialEnd: maxAllowed,
              ),
            ),
          );

          // If user canceled trimming, do not set media
          if (trimmedPath == null) {
            return;
          }

          // Use trimmed file
          finalFile = File(trimmedPath);

          // after returning from trim, show processing overlay again while we initialize the preview
          widget.onProcessing?.call(true);
        }

        // 2) Set file (trimmed or original) and initialize preview player
        if (mounted) {
          setState(() {
            _mediaFile = finalFile;
            _mediaType = mediaType;
            _isPreviewPlaying = false;
            // _isLoadingMedia = true; // Removed internal loading
          });
        }
        widget.onMediaSelected(finalFile, mediaType);

        // Init video controller for preview (overlay stays visible until this finishes)
        _videoController = VideoPlayerController.file(finalFile);
        await _videoController!.initialize();
        _videoController!.addListener(() {
          if (!mounted) return;
          if (!_videoController!.value.isPlaying &&
              _videoController!.value.position >=
                  _videoController!.value.duration) {
            setState(() => _isPreviewPlaying = false);
            _videoController!.seekTo(Duration.zero);
          }
        });

        // if (mounted) {
        //   setState(() => _isLoadingMedia = false); // Removed
        // }
      } catch (e) {
        debugPrint('Error initializing video: $e');
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Failed to load video. Try another file.',
          );
          setState(() {
            _mediaFile = null;
            _mediaType = null;
            // _isLoadingMedia = false; // Removed
          });
          widget.onMediaSelected(null, null);
        }
        await _videoController?.dispose();
        _videoController = null;
      } finally {
        // Done processing – hide overlay regardless of success/failure
        widget.onProcessing?.call(false);
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
      // _isLoadingMedia = false; // Removed
    });
    widget.onMediaSelected(null, null);
  }

  Future<void> _editMedia() async {
    if (_mediaFile == null) return;

    // Pause preview if playing
    if (_mediaType == 'video' &&
        _isPreviewPlaying &&
        _videoController != null) {
      await _videoController!.pause();
      setState(() => _isPreviewPlaying = false);
    }

    if (_mediaType == 'image') {
      // Images: Standard crop
      final croppedFile = await cropImageFile(context, _mediaFile!);
      if (croppedFile != null) {
        setState(() => _mediaFile = croppedFile);
        widget.onMediaSelected(_mediaFile, _mediaType);
      }
    } else if (_mediaType == 'video') {
      // Videos: Trim with limit enforcement via button (no auto if already short)
      final currentDuration = _videoController!.value.duration.inSeconds
          .toDouble();
      final double maxAllowed = Constants.maxVideoDurationSeconds.toDouble();
      final initialEnd = currentDuration.clamp(
        0.0,
        maxAllowed,
      ); // Cap initial for UX

      // Show processing overlay while we navigate / initialize after trimming
      widget.onProcessing?.call(true);

      final trimmedFilePath = await Navigator.of(context).push<String?>(
        MaterialPageRoute<String?>(
          builder: (context) => TrimmerView(
            _mediaFile!,
            maxDuration: maxAllowed,
            initialStart: 0.0, // Always start from 0 for simplicity
            initialEnd: initialEnd,
          ),
        ),
      );

      if (trimmedFilePath != null) {
        await _videoController?.dispose();
        final newFile = File(trimmedFilePath);
        _videoController = VideoPlayerController.file(newFile)
          ..initialize().then((_) => mounted ? setState(() {}) : null);
        setState(() {
          _mediaFile = newFile;
          _isPreviewPlaying = false;
        });
        widget.onMediaSelected(_mediaFile, _mediaType);
      }

      // Done processing after the trimmed video preview initializes (or immediately if cancelled)
      widget.onProcessing?.call(false);
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
        // If media is selected, ignore _isLoadingMedia and show MediaPreview.
        // The full-screen overlay (controlled by onProcessing) handles the loading state.
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
