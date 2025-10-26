import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';
import 'package:go_router/go_router.dart';

class PostMedia extends StatefulWidget {
  final PostEntity post;
  final double? height;
  final bool autoPlay;
  final bool useVisibilityDetector;

  const PostMedia({
    super.key,
    required this.post,
    this.height,
    this.autoPlay = false,
    this.useVisibilityDetector = true,
  });

  @override
  State<PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<PostMedia>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _isInitializing = false;
  final VideoControllerManager _videoManager = VideoControllerManager();
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _ensureControllerInitialized() async {
    if (_isDisposed || !mounted) return;
    if (_videoController != null && _initialized) return;
    if (_isInitializing) return;

    _isInitializing = true;
    try {
      final controller = await _videoManager.getController(
        widget.post.id,
        widget.post.mediaUrl!,
      );

      if (_isDisposed || !mounted) {
        try {
          _videoManager.releaseController(widget.post.id);
        } catch (_) {}
        return;
      }

      if (mounted) {
        setState(() {
          _videoController = controller;
          _initialized = true;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      _isInitializing = false;
      if (mounted) setState(() {});
    }
  }

  void _togglePlayPause() {
    if (_isDisposed || !mounted) return;
    if (_isInitializing) return;

    if (_videoController == null || !_initialized) {
      _ensureControllerInitialized().then((_) {
        if (_videoController != null && mounted && !_isDisposed) {
          VideoPlaybackManager.play(_videoController!, () {
            if (mounted && !_isDisposed) setState(() {});
          });
          if (mounted) setState(() {});
        }
      });
      return;
    }

    final isPlaying = VideoPlaybackManager.isPlaying(_videoController!);
    if (isPlaying) {
      VideoPlaybackManager.pause();
      if (mounted) setState(() {});
    } else {
      VideoPlaybackManager.play(_videoController!, () {
        if (mounted && !_isDisposed) setState(() {});
      });
      if (mounted) setState(() {});
    }
  }

  BoxFit _getBoxFit() {
    return widget.autoPlay ? BoxFit.cover : BoxFit.contain;
  }

  void _openFullMedia(String heroTag) {
    Debouncer.instance.throttle(
      'open_full_${widget.post.id}',
      const Duration(milliseconds: 300),
      () {
        context.push(
          '/media',
          extra: {'post': widget.post, 'heroTag': heroTag},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final heroTag = 'media_${widget.post.id}_${identityHashCode(this)}';
    final double height = widget.height ?? 320.0;

    if (widget.post.mediaType == 'image') {
      return _buildImage(height, heroTag);
    } else if (widget.post.mediaType == 'video') {
      return _buildVideo(height, heroTag);
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildImage(double height, String heroTag) {
    final boxFit = _getBoxFit();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: SizedBox(
                width: double.infinity,
                height: height,
                child: CachedNetworkImage(
                  imageUrl: widget.post.mediaUrl!,
                  fit: boxFit,
                  placeholder: (context, url) => SizedBox(
                    height: height,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: height,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openFullMedia(heroTag),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.open_in_full, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo(double height, String heroTag) {
    final boxFit = _getBoxFit();
    const toggleKeyPrefix = 'toggle_play_';
    const toggleDuration = Duration(milliseconds: 300);

    Widget content = GestureDetector(
      onTap: () => Debouncer.instance.throttle(
        '$toggleKeyPrefix${widget.post.id}',
        toggleDuration,
        _togglePlayPause,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: _initialized && _videoController != null
                  ? FittedBox(
                      fit: boxFit,
                      child: SizedBox(
                        width: _videoController!.value.size.width.toDouble(),
                        height: _videoController!.value.size.height.toDouble(),
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: widget.post.thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.post.thumbnailUrl!,
                              fit: boxFit,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : const Center(
                              child: Icon(Icons.play_circle_outline),
                            ),
                    ),
            ),
            if (!_initialized ||
                (_videoController != null &&
                    !VideoPlaybackManager.isPlaying(_videoController!)))
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 64.0,
                  color: Colors.white,
                ),
              ),
            if (_isInitializing)
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openFullMedia(heroTag),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.open_in_full, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.useVisibilityDetector) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: VisibilityDetector(
          key: Key('post_media_${widget.post.id}_${identityHashCode(this)}'),
          onVisibilityChanged: (info) {
            if (_isDisposed || !mounted) return;
            final visiblePct = info.visibleFraction;
            final controller = _videoController;

            if (visiblePct > 0.4 && !_initialized && !_isInitializing) {
              _ensureControllerInitialized();
            }

            if (controller != null &&
                !_isDisposed &&
                mounted &&
                visiblePct < 0.2 &&
                VideoPlaybackManager.isPlaying(controller)) {
              VideoPlaybackManager.pause();
              if (mounted) setState(() {});
            }
          },
          child: content,
        ),
      );
    }

    return SizedBox(height: height, width: double.infinity, child: content);
  }

  @override
  void dispose() {
    _isDisposed = true;
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      if (VideoPlaybackManager.isPlaying(controller)) {
        VideoPlaybackManager.pause(invokeCallback: false);
      }
      _videoManager.releaseController(widget.post.id);
    }
    super.dispose();
  }
}
