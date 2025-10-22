import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

class PostMedia extends StatefulWidget {
  final PostEntity post;
  final double? height;
  final bool autoPlay;
  const PostMedia({
    super.key,
    required this.post,
    this.height,
    this.autoPlay = false,
  });

  @override
  State<PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<PostMedia>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  final VideoControllerManager _videoManager = VideoControllerManager();
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _ensureControllerInitialized() async {
    if (_isDisposed || !mounted) return;
    if (_videoController != null && _initialized) return;
    try {
      final controller = await _videoManager.getController(
        widget.post.id,
        widget.post.mediaUrl!,
      );
      if (_isDisposed || !mounted) {
        _videoManager.releaseController(widget.post.id);
        return;
      }
      if (mounted) {
        setState(() {
          _videoController = controller;
          _initialized = true;
        });
      }
    } catch (e) {
      // Ignore; fallback to thumbnail
    }
  }

  void _togglePlayPause() {
    if (_isDisposed || !mounted) return;
    if (_videoController == null || !_initialized) return;
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
    // FIX: Use BoxFit.contain for centering without cropping (feeds/details), cover for reels (autoPlay)
    return widget.autoPlay ? BoxFit.cover : BoxFit.contain;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.post.mediaType == 'image') {
      return _buildImage();
    } else if (widget.post.mediaType == 'video') {
      return _buildVideo();
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildImage() {
    final boxFit = _getBoxFit();
    if (widget.height != null) {
      // Full or fixed height mode (e.g., details or reels)
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CachedNetworkImage(
          imageUrl: widget.post.mediaUrl!,
          fit: boxFit,
          placeholder: (context, url) => SizedBox(
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Center(child: Icon(Icons.broken_image)),
          ),
        ),
      );
    } else {
      // Auto height mode (natural aspect for feeds/profile/details)
      return CachedNetworkImage(
        imageUrl: widget.post.mediaUrl!,
        fit: boxFit,
        width: double.infinity,
        placeholder: (context, url) => Container(
          width: double.infinity,
          height: 400, // Estimated height for placeholder
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: double.infinity,
          height: 400,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      );
    }
  }

  Widget _buildVideo() {
    final bool isFixedHeight = widget.height != null;
    final boxFit = _getBoxFit();
    if (isFixedHeight) {
      // Fixed height mode (reels/details)
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: VisibilityDetector(
          key: Key('post_media_${widget.post.id}'),
          onVisibilityChanged: (info) {
            if (_isDisposed || !mounted) return;
            final visiblePct = info.visibleFraction;
            final controller = _videoController;
            if (visiblePct > 0.4 && !_initialized) {
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
            if (widget.autoPlay) {
              if (visiblePct > 0.5) {
                if (!_initialized) {
                  _ensureControllerInitialized();
                }
                if (controller != null &&
                    _initialized &&
                    !VideoPlaybackManager.isPlaying(controller)) {
                  VideoPlaybackManager.play(controller, () {
                    if (mounted && !_isDisposed) setState(() {});
                  });
                  if (mounted) setState(() {});
                }
              } else if (visiblePct < 0.2) {
                if (controller != null &&
                    VideoPlaybackManager.isPlaying(controller)) {
                  VideoPlaybackManager.pause();
                  if (mounted) setState(() {});
                }
              }
            }
          },
          child: GestureDetector(
            onTap: _initialized ? _togglePlayPause : null,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_initialized && _videoController != null)
                    FittedBox(
                      fit: boxFit,
                      child: SizedBox(
                        width: _videoController!.value.size.width.toDouble(),
                        height: _videoController!.value.size.height.toDouble(),
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  else
                    Container(
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
                  if (!_initialized ||
                      !VideoPlaybackManager.isPlaying(_videoController!))
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 64.0,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // Constrained mode (feeds/profile - fixed aspect ratio)
      return AspectRatio(
        aspectRatio:
            1.0, // Square default; adjust as needed (e.g., 4/5 = 0.8 for portrait)
        child: VisibilityDetector(
          key: Key('post_media_${widget.post.id}'),
          onVisibilityChanged: (info) {
            if (_isDisposed || !mounted) return;
            final visiblePct = info.visibleFraction;
            final controller = _videoController;
            if (visiblePct > 0.4 && !_initialized) {
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
            if (widget.autoPlay) {
              if (visiblePct > 0.5) {
                if (!_initialized) {
                  _ensureControllerInitialized();
                }
                if (controller != null &&
                    _initialized &&
                    !VideoPlaybackManager.isPlaying(controller)) {
                  VideoPlaybackManager.play(controller, () {
                    if (mounted && !_isDisposed) setState(() {});
                  });
                  if (mounted) setState(() {});
                }
              } else if (visiblePct < 0.2) {
                if (controller != null &&
                    VideoPlaybackManager.isPlaying(controller)) {
                  VideoPlaybackManager.pause();
                  if (mounted) setState(() {});
                }
              }
            }
          },
          child: GestureDetector(
            onTap: _initialized ? _togglePlayPause : null,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_initialized && _videoController != null)
                    FittedBox(
                      fit: boxFit,
                      child: SizedBox(
                        width: _videoController!.value.size.width.toDouble(),
                        height: _videoController!.value.size.height.toDouble(),
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  else
                    Container(
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
                  if (!_initialized ||
                      !VideoPlaybackManager.isPlaying(_videoController!))
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 64.0,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      if (VideoPlaybackManager.isPlaying(controller)) {
        // Pause without invoking other widget callbacks while we are disposing
        VideoPlaybackManager.pause(invokeCallback: false);
      }
      _videoManager.releaseController(widget.post.id);
    }
    super.dispose();
  }
}
