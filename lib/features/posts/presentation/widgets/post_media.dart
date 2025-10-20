import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

class PostMedia extends StatefulWidget {
  final PostEntity post;
  const PostMedia({super.key, required this.post});
  @override
  State<PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<PostMedia>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  final VideoControllerManager _videoManager = VideoControllerManager();

  // Flag to prevent race conditions during/after disposal
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true; // keep state while scrolling

  Future<void> _ensureControllerInitialized() async {
    // Check flags *before* doing anything
    if (_isDisposed || !mounted) return;
    if (_videoController != null && _initialized) return;

    try {
      final controller = await _videoManager.getController(
        widget.post.id,
        widget.post.mediaUrl!,
      );

      // Check flags *after* await, in case widget was disposed
      if (_isDisposed || !mounted) {
        _videoManager.releaseController(widget.post.id);
        return;
      }

      setState(() {
        _videoController = controller;
        _initialized = true;
      });
    } catch (e) {
      // ignore; show thumbnail/error UI
    }
  }

  void _togglePlayPause() {
    // Check flags
    if (_isDisposed || !mounted) return;
    if (_videoController == null || !_initialized) return;

    final isPlaying = VideoPlaybackManager.isPlaying(_videoController!);
    if (isPlaying) {
      VideoPlaybackManager.pause();
      if (mounted) setState(() {});
    } else {
      VideoPlaybackManager.play(_videoController!, () {
        // Check flags in the playback callback
        if (mounted && !_isDisposed) setState(() {});
      });
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.post.mediaType == 'image') {
      return _buildImage();
    } else if (widget.post.mediaType == 'video') {
      return _buildVideoPlaceholder();
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.post.mediaUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 300,
      placeholder: (context, url) => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        height: 300,
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: const Center(child: Icon(Icons.broken_image)),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return VisibilityDetector(
      key: Key('post_media_${widget.post.id}'),
      onVisibilityChanged: (info) {
        // Check dispose flag *first*
        if (_isDisposed || !mounted) return;

        final visiblePct = info.visibleFraction * 100;

        // Get a local reference to the controller
        final controller = _videoController;

        if (visiblePct > 40 && !_initialized) {
          _ensureControllerInitialized();
        }

        // Check controller is not null AND dispose flag again
        if (controller != null &&
            !_isDisposed &&
            visiblePct < 20 &&
            VideoPlaybackManager.isPlaying(controller)) {
          VideoPlaybackManager.pause();
        }
      },
      child: GestureDetector(
        onTap: _initialized ? _togglePlayPause : null,
        child: AspectRatio(
          aspectRatio: _initialized && _videoController != null
              ? _videoController!.value.aspectRatio
              : (16 / 9),
          child: _initialized && _videoController != null
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoController!),
                    if (!VideoPlaybackManager.isPlaying(_videoController!))
                      const Icon(
                        Icons.play_circle_fill,
                        size: 64.0,
                        color: Colors.white,
                      ),
                  ],
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 300,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: widget.post.thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.post.thumbnailUrl!,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: widget.post.mediaUrl != null
                                  ? Image.network(
                                      widget.post.mediaUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                    ),
                    const Icon(
                      Icons.play_circle_fill,
                      size: 64.0,
                      color: Colors.white,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Set dispose flag *immediately*
    _isDisposed = true;

    if (widget.post.mediaType == 'video') {
      // Get local reference
      final controller = _videoController;

      // Null out the class member to stop other methods from using it
      _videoController = null;

      if (controller != null) {
        // Check if it was playing and pause it
        if (VideoPlaybackManager.isPlaying(controller)) {
          VideoPlaybackManager.pause();
        }
        // Release it from the manager (which *must* call dispose())
        _videoManager.releaseController(widget.post.id);
      }
    }
    super.dispose();
  }
}
