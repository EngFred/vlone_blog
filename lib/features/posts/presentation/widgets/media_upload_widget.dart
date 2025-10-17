import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';

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
  bool _isPreviewPlaying = false; // State to track preview playback

  Future<void> _pickMedia(ImageSource source, bool isImage) async {
    final picker = ImagePicker();
    final pickedFile = isImage
        ? await picker.pickImage(source: source)
        : await picker.pickVideo(source: source);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final mediaType = isImage ? 'image' : 'video';

      await _videoController?.dispose();
      _videoController = null;
      setState(() {
        _isPreviewPlaying = false; // Reset playback state
      });

      if (mediaType == 'video') {
        final duration = await getVideoDuration(file);
        if (duration > Constants.maxVideoDurationSeconds) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video exceeds 10 minutes')),
            );
          }
          return;
        }
        _videoController = VideoPlayerController.file(file)
          ..initialize().then((_) => setState(() {}));

        // Add a listener to reset the play button when the video finishes
        _videoController!.addListener(() {
          if (!_videoController!.value.isPlaying &&
              _videoController!.value.position >=
                  _videoController!.value.duration) {
            setState(() => _isPreviewPlaying = false);
            _videoController!.seekTo(Duration.zero);
          }
        });
      }

      setState(() {
        _mediaFile = file;
        _mediaType = mediaType;
      });
      widget.onMediaSelected(_mediaFile, _mediaType);
    }
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Pick Image from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickMedia(ImageSource.gallery, true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Pick Video from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickMedia(ImageSource.gallery, false);
                },
              ),
            ],
          ),
        );
      },
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

  /// Toggles play/pause for the video preview.
  void _togglePreviewPlayPause() {
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
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _mediaFile == null ? _buildPlaceholder() : _buildPreview();
  }

  Widget _buildPlaceholder() {
    return GestureDetector(
      onTap: _showPickOptions,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400, width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text('Add photo or video', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _mediaType == 'image'
                ? Image.file(
                    _mediaFile!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : (_videoController != null &&
                      _videoController!.value.isInitialized)
                ? GestureDetector(
                    onTap: _togglePreviewPlayPause,
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : Container(
                    height: 200,
                    color: Colors.black,
                    child: const Center(child: LoadingIndicator()),
                  ),
          ),
        ),
        // Show play button overlay for video when not playing
        if (_mediaType == 'video' && !_isPreviewPlaying)
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 64.0,
            ),
            onPressed: _togglePreviewPlayPause,
          ),
        // Remove button
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: _removeMedia,
            ),
          ),
        ),
      ],
    );
  }
}
