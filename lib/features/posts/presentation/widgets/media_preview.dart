import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/presentation/widgets/cutsom_alert_dialog.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';

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

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
    String? tooltip,
  }) {
    // A pill-shaped button with icon + label. Looks modern and "pro" while
    // remaining compact. Uses translucent background to sit nicely over media.
    return Tooltip(
      message: tooltip ?? label,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.35),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final floatingControlBgColor = theme.colorScheme.surface.withOpacity(0.85);
    final floatingControlIconColor = theme.colorScheme.onSurface;

    // Use FittedBox with BoxFit.contain for full-screen immersive preview
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (mediaType == 'image')
              Image.file(file, fit: BoxFit.contain)
            else if (videoController != null &&
                videoController!.value.isInitialized)
              GestureDetector(
                onTap: onPlayPause,
                child: AspectRatio(
                  aspectRatio: videoController!.value.aspectRatio,
                  child: VideoPlayer(videoController!),
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LoadingIndicator(),
                      SizedBox(height: 8),
                      Text('Initializing video...'),
                    ],
                  ),
                ),
              ),

            // Play/Pause Overlay for Video
            if (mediaType == 'video')
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    color: Colors.black.withOpacity(0.28),
                    child: Center(
                      child: GestureDetector(
                        onTap: onPlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: floatingControlBgColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.42),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: floatingControlIconColor,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Action Buttons (improved UI)
            Positioned(
              top: 14,
              right: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit: neutral translucent pill
                  _buildActionButton(
                    context: context,
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onPressed: onEdit,
                    backgroundColor: theme.colorScheme.surface.withOpacity(0.9),
                    foregroundColor: theme.colorScheme.onSurface,
                    tooltip: 'Edit media',
                  ),
                  const SizedBox(width: 8),
                  // Remove: primary destructive pill but slightly elevated
                  _buildActionButton(
                    context: context,
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove',
                    // Show confirmation dialog before calling the provided onRemove
                    onPressed: () async {
                      final confirmed = await showCustomDialog<bool>(
                        context: context,
                        title: 'Remove media',
                        content: const Text(
                          'Are you sure you want to remove this media? This action cannot be undone.',
                        ),
                        actions: [
                          DialogActions.createCancelButton(
                            context,
                            label: 'Cancel',
                          ),
                          DialogActions.createPrimaryButton(
                            context,
                            label: 'Remove',
                            onPressed:
                                () {}, // actual removal is handled after pop
                          ),
                        ],
                        isDismissible: true,
                      );

                      if (confirmed == true) {
                        onRemove();
                      }
                    },
                    backgroundColor: Colors.redAccent.withOpacity(0.95),
                    foregroundColor: Colors.white,
                    tooltip: 'Remove media',
                  ),
                ],
              ),
            ),

            // Video Duration Indicator
            if (mediaType == 'video' && videoController != null)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.68),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(videoController!.value.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
