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

  // Helper widget to create a modern, elevated action chip (like a floating button)
  Widget _buildActionChip({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    required Color buttonColor,
    required Color iconColor,
  }) {
    return Material(
      color: buttonColor,
      borderRadius: BorderRadius.circular(10),
      elevation: 4, // Subtle elevation for a floating look
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use a lighter, semi-transparent color for better contrast against media
    final floatingControlBgColor = theme.colorScheme.surface.withOpacity(0.8);
    final floatingControlIconColor = theme.colorScheme.onSurface;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Media Content (Image or Video)
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

        // 2. Play/Pause Button (Modernized)
        if (mediaType == 'video' && !isPlaying)
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: floatingControlBgColor,
                shape: BoxShape.circle,
                // Add a stronger shadow for a cinematic/prominent play button
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: floatingControlIconColor,
                size: 48.0, // A larger, more compelling icon
              ),
            ),
          ),

        // 3. Grouped Edit and Remove Buttons (Modern Pill/Chip Style)
        Positioned(
          top: 12, // Slightly offset from the corner
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit Button (Right side, top corner)
              _buildActionChip(
                context: context,
                icon: Icons.edit_rounded,
                onPressed: onEdit,
                buttonColor: floatingControlBgColor,
                iconColor: floatingControlIconColor,
              ),
              const SizedBox(width: 8),
              // Remove Button (Right side, top corner)
              _buildActionChip(
                context: context,
                icon: Icons.close_rounded,
                onPressed: onRemove,
                buttonColor: floatingControlBgColor,
                iconColor: floatingControlIconColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
