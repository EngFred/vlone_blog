import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';
import 'package:video_player/video_player.dart';

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

  Future<void> _pickMedia(ImageSource source, bool isImage) async {
    final picker = ImagePicker();
    final pickedFile = isImage
        ? await picker.pickImage(source: source)
        : await picker.pickVideo(source: source);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      String mediaType = isImage ? 'image' : 'video';

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
      }

      setState(() {
        _mediaFile = file;
        _mediaType = mediaType;
      });
      widget.onMediaSelected(_mediaFile, _mediaType);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_mediaFile != null)
          if (_mediaType == 'image')
            Image.file(
              _mediaFile!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          else if (_mediaType == 'video' &&
              _videoController != null &&
              _videoController!.value.isInitialized)
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            )
          else
            const Text('Media selected'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text('Pick Image'),
              onPressed: () => _pickMedia(ImageSource.gallery, true),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('Pick Video'),
              onPressed: () => _pickMedia(ImageSource.gallery, false),
            ),
          ],
        ),
      ],
    );
  }
}
