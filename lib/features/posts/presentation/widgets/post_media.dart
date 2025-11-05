import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

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
  bool _hasError = false;
  final VideoControllerManager _videoManager = VideoControllerManager();
  bool _isDisposed = false;
  bool _isOpeningFull = false;

  // NEW: Add state to track mute status
  bool _isMuted = true;

  double? _aspectRatio;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    try {
      final w = widget.post.mediaWidth;
      final h = widget.post.mediaHeight;
      if (w != null && h != null && w > 0 && h > 0) {
        _aspectRatio = w.toDouble() / h.toDouble();
      } else {
        _aspectRatio = null;
        _hasError = true;
        AppLogger.error(
          'PostMedia: Required media dimensions missing or invalid for post ID: ${widget.post.id}',
        );
      }
    } catch (e) {
      _aspectRatio = null;
      _hasError = true;
      AppLogger.error('PostMedia: Error calculating aspect ratio: $e');
    }

    if (widget.post.mediaType == 'video' && widget.autoPlay) {
      unawaited(Future.microtask(() => _ensureControllerInitialized()));
    }
  }

  Future<void> _ensureControllerInitialized() async {
    if (_isDisposed || !mounted) return;
    if (_videoController != null && _initialized) return;
    if (_isInitializing) return;

    if (widget.post.mediaUrl == null) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    _isInitializing = true;
    _hasError = false;

    try {
      final controller = await _videoManager.getController(
        widget.post.id,
        widget.post.mediaUrl!,
      );

      if (_isDisposed || !mounted) {
        try {
          _videoManager.releaseController(widget.post.id);
        } catch (_) {}
        _isInitializing = false;
        return;
      }

      _videoController = controller;

      await _videoController!.setVolume(_isMuted ? 0.0 : 1.0);

      if (controller.value.isInitialized) {
        _initialized = true;
      } else {
        void listener() {
          if (!mounted) return;
          if (!_initialized && controller.value.isInitialized) {
            _initialized = true;
            setState(() {});
          } else {
            if (mounted) setState(() {});
          }
        }

        controller.addListener(listener);
      }
    } catch (e) {
      AppLogger.info('PostMedia: video init failed: $e');
      _hasError = true;
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
        });
      } else {
        _isInitializing = false;
      }
    }
  }

  // NEW: A dedicated play function that respects the mute state
  void _playVideo() {
    if (_isDisposed || !mounted || _videoController == null || !_initialized) {
      return;
    }
    // Ensure volume is set correctly before playing
    _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    VideoPlaybackManager.play(_videoController!, () {
      if (mounted && !_isDisposed) setState(() {});
    });
    if (mounted) setState(() {});
  }

  // NEW: Function to toggle mute state
  void _toggleMute() {
    if (_isDisposed || !mounted || _videoController == null || !_initialized) {
      return;
    }

    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  // MODIFIED: _togglePlayPause now uses the new _playVideo function
  void _togglePlayPause() {
    if (_isDisposed || !mounted) return;
    if (_isInitializing) return;
    if (_videoController == null || !_videoController!.value.isInitialized) {
      _ensureControllerInitialized().then((_) {
        if (mounted && !_isDisposed) {
          _playVideo(); // Play (will be muted by default)
        }
      });
      return;
    }

    final isPlaying = VideoPlaybackManager.isPlaying(_videoController!);

    if (isPlaying) {
      VideoPlaybackManager.pause();
    } else {
      _playVideo(); // Use the new play function
    }

    if (mounted) setState(() {});
  }

  // REMOVED: _getBoxFit() function is gone.
  // BoxFit _getBoxFit() {
  //   return widget.autoPlay ? BoxFit.cover : BoxFit.contain;
  // }

  void _openFullMedia(String heroTag) async {
    if (_isOpeningFull) return;
    if (widget.post.mediaType == 'video') {
      _videoManager.holdForNavigation(
        widget.post.id,
        const Duration(seconds: 5),
      );
      VideoPlaybackManager.suppressPauseFor(const Duration(seconds: 5));
    }
    setState(() {
      _isOpeningFull = true;
    });
    await context.push(
      '/media',
      extra: {'post': widget.post, 'heroTag': heroTag},
    );
    if (mounted) {
      setState(() {
        _isOpeningFull = false;
      });
    }
  }

  Widget _buildViewButton(String heroTag) {
    // ... (This function is unchanged) ...
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24.0),
            onTap: () => _openFullMedia(heroTag),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.34),
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.open_in_full,
                    size: 16.0,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'View',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 8),
            Text(
              _aspectRatio == null
                  ? 'Missing Dimensions/Media'
                  : 'Media failed to load',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MODIFIED: Removed boxFit parameter, hardcoded BoxFit.cover
  Widget _buildMediaStack(String heroTag) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.post.mediaType == 'image')
          CachedNetworkImage(
            imageUrl: widget.post.mediaUrl!,
            fit: BoxFit.cover, // MODIFIED: Always cover
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          )
        else if (widget.post.mediaType == 'video')
          _initialized &&
                  _videoController != null &&
                  _videoController!.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover, // MODIFIED: Always cover
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              : (widget.post.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.post.thumbnailUrl!,
                        fit: BoxFit.cover, // MODIFIED: Always cover
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline),
                        ),
                      )),

        // ... (Play icon overlay is unchanged) ...
        if (widget.post.mediaType == 'video' &&
            (!(_initialized &&
                _videoController != null &&
                VideoPlaybackManager.isPlaying(_videoController!))))
          Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 64.0,
              color: Colors.white.withOpacity(0.8),
            ),
          ),

        // ... (Initializing indicator is unchanged) ...
        if (_isInitializing)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

        // ... (View button is unchanged) ...
        _buildViewButton(heroTag),

        // NEW: Add a mute/unmute button for videos
        if (widget.post.mediaType == 'video' && _initialized)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              // Add padding to avoid the "View" button
              padding: const EdgeInsets.only(bottom: 8.0, right: 8.0, top: 8.0),
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.4),
                  padding: const EdgeInsets.all(8.0),
                  iconSize: 20.0,
                  shape: const CircleBorder(),
                ),
                onPressed: _toggleMute,
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // MODIFIED: Removed boxFit parameter
  Widget _buildMediaContent(String heroTag) {
    // ... (This function is unchanged) ...
    if (_aspectRatio == null || _hasError) {
      const double fallbackErrorRatio = 16.0 / 9.0;
      return AspectRatio(
        aspectRatio: _aspectRatio ?? fallbackErrorRatio,
        child: _buildErrorContent(),
      );
    }

    final effectiveAspect = _aspectRatio!;

    return AspectRatio(
      aspectRatio: effectiveAspect,
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: _buildMediaStack(heroTag), // MODIFIED: No boxFit
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // ... (heroTag, mediaType definitions are unchanged) ...
    final heroTag = 'media_${widget.post.id}_${identityHashCode(this)}';
    // final boxFit = _getBoxFit(); // REMOVED
    final mediaType = widget.post.mediaType;

    if (mediaType == 'none' ||
        mediaType == null ||
        widget.post.mediaUrl == null) {
      return const SizedBox.shrink();
    }

    final mediaContent = _buildMediaContent(heroTag); // MODIFIED: No boxFit

    // ... (Gesture definitions are unchanged) ...
    VoidCallback? onTap;
    VoidCallback? onDoubleTap;

    if (_aspectRatio != null) {
      if (mediaType == 'image') {
        onTap = () => _openFullMedia(heroTag);
      } else if (mediaType == 'video') {
        onTap = () => Debouncer.instance.throttle(
          'toggle_play_${widget.post.id}',
          const Duration(milliseconds: 300),
          _togglePlayPause,
        );
        onDoubleTap = () => _openFullMedia(heroTag);
      }
    }

    final gestureWrapper = GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: mediaContent,
    );

    // MODIFIED: Updated the onVisibilityChanged logic
    if (mediaType == 'video' && widget.useVisibilityDetector) {
      return VisibilityDetector(
        key: Key('post_media_${widget.post.id}_${identityHashCode(this)}'),
        onVisibilityChanged: (info) {
          if (_isDisposed || !mounted) return;
          final visiblePct = info.visibleFraction;
          final controller = _videoController;

          // MODIFIED: Auto-play logic
          if (visiblePct > 0.4) {
            if (!_initialized &&
                !_isInitializing &&
                !_hasError &&
                _aspectRatio != null) {
              // 1. Initialize if not already
              _ensureControllerInitialized().then((_) {
                // 2. Once initialized, play (it will be muted)
                if (mounted && !_isDisposed) {
                  _playVideo();
                }
              });
            } else if (_initialized &&
                controller != null &&
                !VideoPlaybackManager.isPlaying(controller)) {
              // 3. If already initialized but paused, play it
              _playVideo();
            }
          }

          // MODIFIED: Pause logic (this is still correct)
          if (controller != null &&
              !_isDisposed &&
              mounted &&
              visiblePct < 0.2 && // Pause when less than 20% visible
              VideoPlaybackManager.isPlaying(controller) &&
              controller.value.isInitialized) {
            if (!_isOpeningFull && !VideoPlaybackManager.pauseSuppressed) {
              VideoPlaybackManager.pause();
              if (mounted) setState(() {});
            }
          }
        },
        child: gestureWrapper,
      );
    }

    // For images, just return the gesture wrapper (unchanged)
    return gestureWrapper;
  }

  @override
  void dispose() {
    // ... (This function is unchanged) ...
    _isDisposed = true;

    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      try {
        if (VideoPlaybackManager.isPlaying(controller) &&
            (controller.value.isInitialized)) {
          VideoPlaybackManager.pause(invokeCallback: false);
        }
      } catch (_) {}
      try {
        _videoManager.releaseController(widget.post.id);
      } catch (_) {}
    }
    super.dispose();
  }
}
