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

  @override
  bool get wantKeepAlive => true; // keep state while scrolling

  Future<void> _ensureControllerInitialized() async {
    if (_videoController != null && _initialized) return;
    try {
      final controller = await _videoManager.getController(
        widget.post.id,
        widget.post.mediaUrl!,
      );
      if (!mounted) {
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
    if (_videoController == null || !_initialized) return;
    final isPlaying = VideoPlaybackManager.isPlaying(_videoController!);
    if (isPlaying) {
      VideoPlaybackManager.pause();
      setState(() {});
    } else {
      VideoPlaybackManager.play(_videoController!, () {
        if (mounted) setState(() {});
      });
      setState(() {});
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
        final visiblePct = info.visibleFraction * 100;
        if (visiblePct > 40 && !_initialized) {
          _ensureControllerInitialized();
        }
        if (visiblePct < 20 &&
            _videoController != null &&
            VideoPlaybackManager.isPlaying(_videoController!)) {
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
    if (widget.post.mediaType == 'video') {
      _videoManager.releaseController(widget.post.id);
      if (_videoController != null &&
          VideoPlaybackManager.isPlaying(_videoController!)) {
        VideoPlaybackManager.pause();
      }
    }
    super.dispose();
  }
}
