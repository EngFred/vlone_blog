import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';
import 'package:go_router/go_router.dart';

/// Full replacement of PostMedia
/// - **Strictly relies** on server-provided mediaWidth/mediaHeight being available and correct.
/// - Uses AspectRatio based *only* on server-provided dimensions.
/// - If dimensions are missing, it defaults to an error state immediately.
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

  // Aspect ratio is now nullable and relies ONLY on server dimensions.
  double? _aspectRatio;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // **STRICT RELIANCE APPLIED**: Calculate aspect ratio from dimensions or set error.
    try {
      final w = widget.post.mediaWidth;
      final h = widget.post.mediaHeight;
      // Strict check for valid positive dimensions
      if (w != null && h != null && w > 0 && h > 0) {
        _aspectRatio = w.toDouble() / h.toDouble();
      } else {
        // If the assumption fails (dimensions are null or <= 0),
        // we set _aspectRatio to null and immediately flag an error.
        _aspectRatio = null;
        _hasError = true;
        AppLogger.error(
          'PostMedia: Required media dimensions missing or invalid for post ID: ${widget.post.id}',
        );
      }
    } catch (e) {
      // In case of any casting error, set error.
      _aspectRatio = null;
      _hasError = true;
      AppLogger.error('PostMedia: Error calculating aspect ratio: $e');
    }

    // If it's a video and autoPlay is requested, start initializing the controller
    if (widget.post.mediaType == 'video' && widget.autoPlay) {
      // Delay to let build finish in some cases
      unawaited(Future.microtask(() => _ensureControllerInitialized()));
    }
  }

  // _loadImageAspectRatio method is REMOVED (from previous iteration).

  Future<void> _ensureControllerInitialized() async {
    if (_isDisposed || !mounted) return;
    if (_videoController != null && _initialized) return;
    if (_isInitializing) return;

    // Safety check: Don't try to init if mediaUrl isn't there
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

      // Set initial initialized flag based on controller state
      if (controller.value.isInitialized) {
        _initialized = true;
      } else {
        // Listen for initialization
        void listener() {
          if (!mounted) return;
          if (!_initialized && controller.value.isInitialized) {
            _initialized = true;
            // still trigger rebuild for play/pause overlay changes
            setState(() {});
          } else {
            // rebuild for play/pause overlay changes
            if (mounted) setState(() {});
          }
        }

        controller.addListener(listener);

        // remove listener when disposed/cleanup
        // We don't remove it here; _videoManager.releaseController will handle cleanup
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

  void _togglePlayPause() {
    if (_isDisposed || !mounted) return;
    if (_isInitializing) return;
    if (_videoController == null || !_videoController!.value.isInitialized) {
      _ensureControllerInitialized().then((_) {
        if (_videoController != null &&
            mounted &&
            !_isDisposed &&
            _videoController!.value.isInitialized) {
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
      if (_videoController!.value.isInitialized) {
        VideoPlaybackManager.pause();
      }
    } else {
      if (_videoController!.value.isInitialized) {
        VideoPlaybackManager.play(_videoController!, () {
          if (mounted && !_isDisposed) setState(() {});
        });
      }
    }

    if (mounted) setState(() {});
  }

  BoxFit _getBoxFit() {
    return widget.autoPlay ? BoxFit.cover : BoxFit.contain;
  }

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
    // We use AspectRatio wrapper outside; caller controls height via AspectRatio.
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
              // Updated text to reflect strict dimension requirement
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

  Widget _buildMediaStack(String heroTag, BoxFit boxFit) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.post.mediaType == 'image')
          CachedNetworkImage(
            imageUrl: widget.post.mediaUrl!,
            fit: boxFit,
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
              ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
              : (widget.post.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.post.thumbnailUrl!,
                        fit: boxFit,
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
        // Play icon overlay for videos when not actively playing
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
        if (_isInitializing)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        // Always show 'View' button if mediaUrl is present (i.e., completed)
        _buildViewButton(heroTag),
      ],
    );
  }

  Widget _buildMediaContent(String heroTag, BoxFit boxFit) {
    // **STRICT CHECK:** If _aspectRatio is null (meaning dimensions were missing in initState),
    // or if a runtime error has occurred, show the error content.
    if (_aspectRatio == null || _hasError) {
      // Use a reasonable fallback for the error display container if dimensions are missing entirely
      const double fallbackErrorRatio = 16.0 / 9.0;
      return AspectRatio(
        aspectRatio: _aspectRatio ?? fallbackErrorRatio,
        child: _buildErrorContent(),
      );
    }

    final effectiveAspect = _aspectRatio!;

    return AspectRatio(
      aspectRatio: effectiveAspect,
      child: GestureDetector(
        onTap: widget.post.mediaType == 'image'
            ? () => _openFullMedia(heroTag)
            : null,
        onDoubleTap: widget.post.mediaType == 'video'
            ? () => _openFullMedia(heroTag)
            : null,
        onLongPress: () {
          // keep existing behavior: treat tap/double-tap for video play/pause via Debouncer
        },
        child: Hero(
          tag: heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: _buildMediaStack(heroTag, boxFit),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final heroTag = 'media_${widget.post.id}_${identityHashCode(this)}';
    final boxFit = _getBoxFit();

    final mediaType = widget.post.mediaType;

    // 1. If no media type (text-only post), render nothing.
    if (mediaType == 'none' ||
        mediaType == null ||
        widget.post.mediaUrl == null) {
      return const SizedBox.shrink();
    }

    // 3. Proceed with existing video/image logic (all posts here are considered "completed")
    if (mediaType == 'video') {
      final content = _buildMediaContent(heroTag, boxFit);
      if (widget.useVisibilityDetector) {
        return VisibilityDetector(
          key: Key('post_media_${widget.post.id}_${identityHashCode(this)}'),
          onVisibilityChanged: (info) {
            if (_isDisposed || !mounted) return;
            final visiblePct = info.visibleFraction;
            final controller = _videoController;

            // Initialize when sufficiently visible
            if (visiblePct > 0.4 &&
                !_initialized &&
                !_isInitializing &&
                !_hasError &&
                _aspectRatio != null) {
              // Added check for valid dimensions
              _ensureControllerInitialized();
            }

            // Pause logic
            if (controller != null &&
                !_isDisposed &&
                mounted &&
                visiblePct < 0.2 &&
                VideoPlaybackManager.isPlaying(controller) &&
                controller.value.isInitialized) {
              if (!_isOpeningFull && !VideoPlaybackManager.pauseSuppressed) {
                VideoPlaybackManager.pause();
                if (mounted) setState(() {});
              }
            }
          },
          child: GestureDetector(
            // Only allow interaction if we have a valid aspect ratio (dimensions)
            onTap: _aspectRatio != null
                ? () => Debouncer.instance.throttle(
                    'toggle_play_${widget.post.id}',
                    const Duration(milliseconds: 300),
                    _togglePlayPause,
                  )
                : null,
            onDoubleTap: _aspectRatio != null
                ? () => _openFullMedia(heroTag)
                : null,
            child: content,
          ),
        );
      } else {
        return GestureDetector(
          // Only allow interaction if we have a valid aspect ratio (dimensions)
          onTap: _aspectRatio != null
              ? () => Debouncer.instance.throttle(
                  'toggle_play_${widget.post.id}',
                  const Duration(milliseconds: 300),
                  _togglePlayPause,
                )
              : null,
          onDoubleTap: _aspectRatio != null
              ? () => _openFullMedia(heroTag)
              : null,
          child: content,
        );
      }
    }

    // For images: display immediately.
    if (mediaType == 'image') {
      return _buildMediaContent(heroTag, boxFit);
    }

    return const SizedBox.shrink();
  }

  @override
  void dispose() {
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
