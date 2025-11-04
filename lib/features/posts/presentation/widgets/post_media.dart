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
  bool _hasError = false;
  final VideoControllerManager _videoManager = VideoControllerManager();
  bool _isDisposed = false;
  bool _isOpeningFull = false;

  double? _aspectRatio;

  // Trackers for image stream cleanup
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // 1) Prefer server-provided dimensions (immediate)
    try {
      final w = widget.post.mediaWidth;
      final h = widget.post.mediaHeight;
      if (w != null && h != null && w > 0 && h > 0) {
        _aspectRatio = w.toDouble() / h.toDouble();
      }
    } catch (_) {
      // ignore and continue to fallback
    }

    // 2) If we don't have server dims and it's an image, attempt to load image dimensions (async)
    if (_aspectRatio == null && widget.post.mediaType == 'image') {
      // Check for mediaUrl presence implicitly handled inside _loadImageAspectRatio
      _loadImageAspectRatio();
    }
    // For video: we'll set aspect ratio after controller initialization if available
  }

  void _loadImageAspectRatio() {
    if (widget.post.mediaUrl == null) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      return;
    }

    final imageProvider = CachedNetworkImageProvider(widget.post.mediaUrl!);

    _imageStreamListener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (mounted && _aspectRatio == null) {
          final newAspectRatio =
              info.image.width.toDouble() / info.image.height.toDouble();
          setState(() {
            _aspectRatio = newAspectRatio;
          });
        }
        _imageStream?.removeListener(_imageStreamListener!);
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
        _imageStream?.removeListener(_imageStreamListener!);
      },
    );

    _imageStream = imageProvider.resolve(const ImageConfiguration());
    _imageStream!.addListener(_imageStreamListener!);
  }

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
      _initialized = true;

      // If we don't already have an aspect ratio, set from video controller
      if (widget.post.mediaType == 'video' &&
          _aspectRatio == null &&
          controller.value.isInitialized) {
        setState(() {
          _aspectRatio = controller.value.aspectRatio;
        });
      } else {
        // If controller isn't initialized yet, listen for initialization
        if (widget.post.mediaType == 'video' &&
            !controller.value.isInitialized) {
          controller.addListener(() {
            if (!mounted) return;
            if (_aspectRatio == null && controller.value.isInitialized) {
              setState(() {
                _aspectRatio = controller.value.aspectRatio;
              });
            }
            // when playing state changes, rebuild to update play button overlay etc
            if (mounted) setState(() {});
          });
        }
      }
    } catch (e) {
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
    if (_videoController == null ||
        !_initialized ||
        !_videoController!.value.isInitialized) {
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
              'Media failed to load',
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
              ? FittedBox(
                  fit: boxFit,
                  child: SizedBox(
                    width: _videoController!.value.size.width.toDouble(),
                    height: _videoController!.value.size.height.toDouble(),
                    child: VideoPlayer(_videoController!),
                  ),
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
    if (_hasError) {
      final fallback = _aspectRatio ?? 1.0;
      return AspectRatio(aspectRatio: fallback, child: _buildErrorContent());
    }

    final effectiveAspect = _aspectRatio ?? 1.0;

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

    // 🌟 REMOVED: final uploadStatus = widget.post.uploadStatus;
    final mediaType = widget.post.mediaType;

    // 1. If no media type (text-only post), render nothing.
    // 2. If mediaType exists but mediaUrl is missing (the new "failed/processing" state, if the DB record was created too early), render nothing or an error.
    if (mediaType == 'none' ||
        mediaType == null ||
        widget.post.mediaUrl == null) {
      // In the new world, if a media-type post has no mediaUrl, it's an error/incomplete state.
      // Since the post only exists *after* the worker runs, this shouldn't happen often.
      // We will default to a blank space (SizedBox.shrink) for safety, but you could show an error here if desired.
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
                !_hasError) {
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
            onTap: () => Debouncer.instance.throttle(
              'toggle_play_${widget.post.id}',
              const Duration(milliseconds: 300),
              _togglePlayPause,
            ),
            onDoubleTap: () => _openFullMedia(heroTag),
            child: content,
          ),
        );
      } else {
        return GestureDetector(
          onTap: () => Debouncer.instance.throttle(
            'toggle_play_${widget.post.id}',
            const Duration(milliseconds: 300),
            _togglePlayPause,
          ),
          onDoubleTap: () => _openFullMedia(heroTag),
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
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }

    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      if (VideoPlaybackManager.isPlaying(controller) &&
          (controller.value.isInitialized)) {
        VideoPlaybackManager.pause(invokeCallback: false);
      }
      _videoManager.releaseController(widget.post.id);
    }
    super.dispose();
  }
}
