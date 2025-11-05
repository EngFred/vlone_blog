import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/crop_utils.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/media_file_type.dart';
import 'media_picker_sheet.dart';
import 'media_placeholder.dart';
import 'media_preview.dart';
import 'trimmer_view.dart';
import 'dart:async'; // FIX: For TimeoutException

class MediaUploadWidget extends StatefulWidget {
  final File? selectedMediaFile; // FIX: Issue 1 - Prop from Bloc for state sync
  final MediaType?
  selectedMediaType; // FIX: Issue 1 - Prop from Bloc for state sync
  final Function(File?, MediaType?) onMediaSelected;

  /// Optional callback used to notify parent that media processing (duration fetch,
  /// video initialization, trimming flow) is underway. Parent should show a
  /// full-screen overlay when true.
  final void Function(bool isProcessing)? onProcessing;

  const MediaUploadWidget({
    super.key,
    this.selectedMediaFile,
    this.selectedMediaType,
    required this.onMediaSelected,
    this.onProcessing,
  });

  @override
  State<MediaUploadWidget> createState() => _MediaUploadWidgetState();
}

class _MediaUploadWidgetState extends State<MediaUploadWidget> {
  File? _mediaFile;
  MediaType? _mediaType;
  VideoPlayerController? _videoController;
  bool _isPreviewPlaying = false;

  @override
  void initState() {
    super.initState();
    // FIX: Issue 1 - Initialize local state from Bloc props on mount
    _mediaFile = widget.selectedMediaFile;
    _mediaType = widget.selectedMediaType;
    _initVideoControllerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MediaUploadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // FIX: Issue 1 - Sync local state if Bloc props change (e.g., on reselection or external updates)
    if (widget.selectedMediaFile?.path != oldWidget.selectedMediaFile?.path ||
        widget.selectedMediaType != oldWidget.selectedMediaType) {
      // Dispose old controller if media changes or becomes null
      if (_videoController != null) {
        _videoController!.removeListener(_videoListener);
        _videoController!.dispose();
        _videoController = null;
      }
      _mediaFile = widget.selectedMediaFile;
      _mediaType = widget.selectedMediaType;
      _isPreviewPlaying = false;
      _initVideoControllerIfNeeded();
    }
  }

  // FIX: Issue 1 & 2 - Async init for video if pre-selected, with error handling
  Future<void> _initVideoControllerIfNeeded() async {
    if (_mediaType == MediaType.video &&
        _mediaFile != null &&
        _videoController == null) {
      try {
        _videoController = VideoPlayerController.file(_mediaFile!);
        await _videoController!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Video initialization timed out');
          },
        );
        _videoController!.addListener(_videoListener);
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint(
          'Failed to init pre-selected video: $e',
        ); // FIX: Production logging
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Failed to load video. Try another file.',
          );
          // FIX: Update Bloc instead of local setState to drive UI via props
          widget.onMediaSelected(null, null);
        }
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;
    if (_videoController == null) return;
    if (!_videoController!.value.isPlaying &&
        _videoController!.value.position >= _videoController!.value.duration) {
      setState(() => _isPreviewPlaying = false);
      _videoController!.seekTo(Duration.zero);
    }
  }

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
    final mediaType = isImage ? MediaType.image : MediaType.video;

    await _videoController?.dispose();
    _videoController = null;

    // Notify parent that processing is starting (show full-screen overlay)
    widget.onProcessing?.call(true);

    if (mediaType == MediaType.image) {
      // Images: Quick validation and set (no duration check needed)
      try {
        final imageBytes = await file.readAsBytes();
        await decodeImageFromList(imageBytes);
        if (mounted) {
          setState(() {
            _mediaFile = file;
            _mediaType = mediaType;
            _isPreviewPlaying = false;
          });
          widget.onMediaSelected(
            file,
            mediaType,
          ); // Update Bloc after local for initial set
        }
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
          });
          widget.onMediaSelected(
            finalFile,
            mediaType,
          ); // Update Bloc after local for initial set
        }

        // Init video controller for preview (overlay stays visible until this finishes)
        _videoController = VideoPlayerController.file(finalFile);
        await _videoController!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Video initialization timed out');
          },
        );
        _videoController!.addListener(_videoListener);
      } catch (e) {
        debugPrint('Error initializing video: $e'); // FIX: Production logging
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Failed to load video. Try another file.',
          );
          // FIX: Update Bloc instead of local setState to drive UI via props
          widget.onMediaSelected(null, null);
        }
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
    debugPrint('Removing media'); // FIX: Logging for debugging
    // Dispose controller and immediately update local state for responsive UI (show placeholder without waiting for BLoC rebuild)
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _mediaFile = null;
      _mediaType = null;
    });
    // Still update BLoC for global form state consistency
    widget.onMediaSelected(null, null);
  }

  Future<void> _editMedia() async {
    if (_mediaFile == null) return;

    // Pause preview if playing
    if (_mediaType == MediaType.video &&
        _isPreviewPlaying &&
        _videoController != null) {
      await _videoController!.pause();
      setState(() => _isPreviewPlaying = false);
    }

    if (_mediaType == MediaType.image) {
      // Images: Standard crop
      final croppedFile = await cropImageFile(context, _mediaFile!);
      if (croppedFile != null) {
        setState(() => _mediaFile = croppedFile);
        widget.onMediaSelected(_mediaFile, _mediaType);
      }
    } else if (_mediaType == MediaType.video) {
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
        _videoController?.removeListener(_videoListener);
        await _videoController?.dispose();
        final newFile = File(trimmedFilePath);
        _videoController = VideoPlayerController.file(newFile);
        await _videoController!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Video initialization timed out');
          },
        );
        _videoController!.addListener(_videoListener);
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
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When media is selected we enforce a dark background for a professional
    // media-focused experience regardless of app theme. Keep the placeholder
    // behavior unchanged when no media is present.
    return _mediaFile == null
        ? MediaPlaceholder(onTap: _showPickOptions)
        : Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: MediaPreview(
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
              ),
            ),
          );
  }
}
