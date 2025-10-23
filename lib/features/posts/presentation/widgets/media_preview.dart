import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';

class MediaPreview extends StatelessWidget {
  final File file;
  final String mediaType;
  final VideoPlayerController? videoController;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const MediaPreview({
    super.key,
    required this.file,
    required this.mediaType,
    required this.videoController,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onRemove,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final buttonBackgroundColor = Theme.of(
      context,
    ).colorScheme.background.withOpacity(0.6);

    return Stack(
      alignment: Alignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: mediaType == 'image'
                ? Image.file(file, width: double.infinity, fit: BoxFit.cover)
                : (videoController != null &&
                      videoController!.value.isInitialized)
                ? GestureDetector(
                    onTap: onPlayPause,
                    child: AspectRatio(
                      aspectRatio: videoController!.value.aspectRatio,
                      child: VideoPlayer(videoController!),
                    ),
                  )
                : Container(
                    height: 200,
                    color: Colors.black,
                    child: const Center(child: LoadingIndicator()),
                  ),
          ),
        ),
        if (mediaType == 'video' && !isPlaying)
          GestureDetector(
            onTap: onPlayPause,
            child: CircleAvatar(
              radius: 32,
              backgroundColor: buttonBackgroundColor,
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 44.0,
              ),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: buttonBackgroundColor,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: onRemove,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: buttonBackgroundColor,
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white, size: 20),
              onPressed: onEdit,
            ),
          ),
        ),
      ],
    );
  }
}
