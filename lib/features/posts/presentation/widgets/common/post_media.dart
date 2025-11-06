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

/// A widget responsible for displaying a post's media (image or video).
///
/// It handles video initialization, playback, visibility-based auto-play/pause,
/// and navigation to a full-screen media view.
class PostMedia extends StatefulWidget {
  /// The post entity containing media details.
  final PostEntity post;

  /// Optional fixed height for the media container. Not currently used for aspect ratio enforcement.
  final double? height;

  /// Determines if the video should attempt to auto-play on load (overridden by visibility detection).
  final bool autoPlay;

  /// Controls whether visibility detection is used for auto-play/pause logic.
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
  /// The controller for video playback. It's managed by [VideoControllerManager].
  VideoPlayerController? _videoController;

  /// Flag indicating if the video controller has completed initialization.
  bool _initialized = false;

  /// Flag indicating if the controller initialization process is currently running.
  bool _isInitializing = false;

  /// Flag indicating if there was an error during aspect ratio calculation or media loading.
  bool _hasError = false;

  /// Manager responsible for getting and releasing shared video controllers.
  final VideoControllerManager _videoManager = VideoControllerManager();

  /// Flag to prevent asynchronous operations from running after dispose.
  bool _isDisposed = false;

  /// Flag to prevent opening full media multiple times during an in-progress navigation.
  bool _isOpeningFull = false;

  /// Tracks the current mute status of the video player. Videos auto-play muted.
  bool _isMuted = true;

  /// The calculated aspect ratio of the media (width / height).
  double? _aspectRatio;

  /// Keeps the state of the widget alive when it scrolls out of view (e.g., in a ListView).
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _calculateAspectRatio();

    // Trigger initial video controller setup if it's a video and autoPlay is requested.
    if (widget.post.mediaType == 'video' && widget.autoPlay) {
      unawaited(Future.microtask(_ensureControllerInitialized));
    }
  }

  /// Calculates the media's aspect ratio based on post dimensions.
  void _calculateAspectRatio() {
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
  }

  /// Ensures the video controller is initialized and ready for playback.
  ///
  /// This function uses the [VideoControllerManager] to handle controller lifecycle.
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

      // Checking state again as 'await' introduced a potential gap.
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
        // Attaching a listener to wait for initialization completion.
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
      // Ensuring the loading state is updated.
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
        });
      } else {
        _isInitializing = false;
      }
    }
  }

  /// Plays the video, respecting the current mute state.
  void _playVideo() {
    if (_isDisposed || !mounted || _videoController == null || !_initialized) {
      return;
    }
    // Ensuring volume is set correctly before playing.
    _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    VideoPlaybackManager.play(_videoController!, () {
      if (mounted && !_isDisposed) setState(() {});
    });
    if (mounted) setState(() {});
  }

  /// Toggles the mute state and updates the video controller's volume.
  void _toggleMute() {
    if (_isDisposed || !mounted || _videoController == null || !_initialized) {
      return;
    }

    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  /// Toggles between playing and pausing the video.
  ///
  /// If the controller is not yet initialized, it triggers initialization and then plays.
  void _togglePlayPause() {
    if (_isDisposed || !mounted) return;
    if (_isInitializing) return;
    if (_videoController == null || !_videoController!.value.isInitialized) {
      _ensureControllerInitialized().then((_) {
        if (mounted && !_isDisposed) {
          _playVideo(); // Playing the video, which is muted by default.
        }
      });
      return;
    }

    final isPlaying = VideoPlaybackManager.isPlaying(_videoController!);

    if (isPlaying) {
      VideoPlaybackManager.pause();
    } else {
      _playVideo(); // Using the dedicated play function.
    }

    if (mounted) setState(() {});
  }

  /// Navigates to the full-screen media view.
  ///
  /// It holds the video controller during navigation to prevent premature release/pause.
  void _openFullMedia(String heroTag) async {
    if (_isOpeningFull) return;

    if (widget.post.mediaType == 'video') {
      // Holding the controller to keep it alive during navigation.
      _videoManager.holdForNavigation(
        widget.post.id,
        const Duration(seconds: 5),
      );
      // Suppressing global pause logic that might trigger during the transition.
      VideoPlaybackManager.suppressPauseFor(const Duration(seconds: 5));
    }

    setState(() {
      _isOpeningFull = true;
    });

    await context.push(
      '/media',
      extra: {'post': widget.post, 'heroTag': heroTag},
    );

    // Resetting the flag after navigation returns.
    if (mounted) {
      setState(() {
        _isOpeningFull = false;
      });
    }
  }

  /// Builds the 'View' button overlay to open the media in full-screen.
  Widget _buildViewButton(String heroTag) {
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

  /// Builds the content displayed when media loading fails or dimensions are missing.
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

  /// Builds the stack containing the actual media (image or video) and all its overlays.
  Widget _buildMediaStack(String heroTag) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.post.mediaType == 'image')
          // Displaying network image using CachedNetworkImage.
          CachedNetworkImage(
            imageUrl: widget.post.mediaUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          )
        else if (widget.post.mediaType == 'video')
          // Conditional rendering for initialized video player or placeholder/thumbnail.
          _initialized &&
                  _videoController != null &&
                  _videoController!.value.isInitialized
              ? FittedBox(
                  // Using FittedBox to display the video, ensuring it covers the area.
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              : (widget.post.thumbnailUrl != null
                    // Displaying the video thumbnail if available.
                    ? CachedNetworkImage(
                        imageUrl: widget.post.thumbnailUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    // Fallback placeholder when no thumbnail is available.
                    : Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline),
                        ),
                      )),

        // Play icon overlay for videos when not playing.
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

        // Initialization indicator overlay.
        if (_isInitializing)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

        // Full-screen view button.
        _buildViewButton(heroTag),

        // Mute/unmute button overlay for videos after initialization.
        if (widget.post.mediaType == 'video' && _initialized)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              // Adding padding to position it away from the 'View' button.
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

  /// Builds the main media content wrapper, applying the aspect ratio and Hero transition.
  Widget _buildMediaContent(String heroTag) {
    if (_aspectRatio == null || _hasError) {
      // Providing a common fallback ratio for error state.
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
          child: _buildMediaStack(heroTag),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Creating a unique hero tag for the current media instance.
    final heroTag = 'media_${widget.post.id}_${identityHashCode(this)}';
    final mediaType = widget.post.mediaType;

    // Hiding the widget if media details are invalid or missing.
    if (mediaType == 'none' ||
        mediaType == null ||
        widget.post.mediaUrl == null) {
      return const SizedBox.shrink();
    }

    final mediaContent = _buildMediaContent(heroTag);

    VoidCallback? onTap;
    VoidCallback? onDoubleTap;

    if (_aspectRatio != null) {
      if (mediaType == 'image') {
        // Tap on an image opens the full-screen view.
        onTap = () => _openFullMedia(heroTag);
      } else if (mediaType == 'video') {
        // Throttling single tap for play/pause to avoid accidental multiple triggers.
        onTap = () => Debouncer.instance.throttle(
          'toggle_play_${widget.post.id}',
          const Duration(milliseconds: 300),
          _togglePlayPause,
        );
        // Double tap on a video opens the full-screen view.
        onDoubleTap = () => _openFullMedia(heroTag);
      }
    }

    final gestureWrapper = GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: mediaContent,
    );

    // Applying visibility detection only for videos when enabled.
    if (mediaType == 'video' && widget.useVisibilityDetector) {
      return VisibilityDetector(
        key: Key('post_media_${widget.post.id}_${identityHashCode(this)}'),
        onVisibilityChanged: (info) {
          if (_isDisposed || !mounted) return;
          final visiblePct = info.visibleFraction;
          final controller = _videoController;

          // Logic for auto-playing the video when visibility is high (e.g., > 40%).
          if (visiblePct > 0.4) {
            if (!_initialized &&
                !_isInitializing &&
                !_hasError &&
                _aspectRatio != null) {
              // 1. Initializing the controller if needed.
              _ensureControllerInitialized().then((_) {
                // 2. Once initialized, starting playback (muted).
                if (mounted && !_isDisposed) {
                  _playVideo();
                }
              });
            } else if (_initialized &&
                controller != null &&
                !VideoPlaybackManager.isPlaying(controller)) {
              // 3. If initialized but paused, resuming playback.
              _playVideo();
            }
          }

          // Pausing the video when visibility drops too low (e.g., < 20%).
          if (controller != null &&
              !_isDisposed &&
              mounted &&
              visiblePct < 0.2 &&
              VideoPlaybackManager.isPlaying(controller) &&
              controller.value.isInitialized) {
            // Preventing pause if navigation to full-screen is in progress or pause is temporarily suppressed.
            if (!_isOpeningFull && !VideoPlaybackManager.pauseSuppressed) {
              VideoPlaybackManager.pause();
              if (mounted) setState(() {});
            }
          }
        },
        child: gestureWrapper,
      );
    }

    // Returning the media wrapper directly for images or when visibility detection is disabled.
    return gestureWrapper;
  }

  @override
  void dispose() {
    _isDisposed = true;

    final controller = _videoController;
    _videoController = null;

    if (controller != null) {
      try {
        // Pausing the video if it was playing before disposal.
        if (VideoPlaybackManager.isPlaying(controller) &&
            (controller.value.isInitialized)) {
          VideoPlaybackManager.pause(invokeCallback: false);
        }
      } catch (_) {}
      try {
        // Releasing the controller back to the manager for potential reuse.
        _videoManager.releaseController(widget.post.id);
      } catch (_) {}
    }
    super.dispose();
  }
}
