import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

class ReelVideoPlayer extends StatefulWidget {
  final PostEntity post;
  final bool isActive;
  final bool shouldPreload;

  const ReelVideoPlayer({
    super.key,
    required this.post,
    required this.isActive,
    this.shouldPreload = false,
  });

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _isDisposed = false;
  bool _isInitializing = false; //Prevent double initialization
  final VideoControllerManager _videoManager = VideoControllerManager();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive || widget.shouldPreload) {
      _initializeIfNeeded();
    }
  }

  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (!_initialized && !_isInitializing) {
          _initializeIfNeeded().then((_) {
            if (mounted && widget.isActive) {
              _playVideo();
            }
          });
        } else if (_initialized) {
          _playVideo();
        }
      } else {
        _pauseVideo();
      }
    }

    if (widget.shouldPreload != oldWidget.shouldPreload) {
      if (widget.shouldPreload && !_initialized && !_isInitializing) {
        _initializeIfNeeded();
      }
    }
  }

  Future<void> _initializeIfNeeded() async {
    if (_isDisposed || !mounted) return;
    if (_initialized || _videoController != null) return;
    if (_isInitializing) return;

    if (!widget.isActive && !widget.shouldPreload) return;

    _isInitializing = true;
    AppLogger.info('Initializing video controller for post: ${widget.post.id}');

    try {
      final controller = await _videoManager.getController(
        widget.post.id,
        widget.post.mediaUrl!,
      );

      if (_isDisposed || !mounted) {
        _videoManager.releaseController(widget.post.id);
        _isInitializing = false;
        return;
      }

      if (mounted) {
        setState(() {
          _videoController = controller;
          _initialized = true;
          _isInitializing = false;
        });

        AppLogger.info(
          'Video controller initialized for post: ${widget.post.id}, isActive: ${widget.isActive}',
        );

        if (widget.isActive &&
            mounted &&
            !VideoPlaybackManager.isPlaying(controller)) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && widget.isActive && !_isDisposed) {
              _playVideo();
            }
          });
        }
      }
    } catch (e) {
      AppLogger.error('Failed to initialize video controller: $e');
      _isInitializing = false;
      // silently fall back to thumbnail
      if (mounted) setState(() {});
    }
  }

  void _playVideo() {
    if (_isDisposed || !mounted) return;
    if (!_initialized && _videoController == null) {
      AppLogger.warning('Cannot play video - not initialized yet');
      return;
    }

    if (_videoController != null && _initialized) {
      AppLogger.info('Playing video for post: ${widget.post.id}');
      VideoPlaybackManager.play(_videoController!, () {
        if (mounted && !_isDisposed) setState(() {});
      });
      if (mounted) setState(() {});
    }
  }

  void _pauseVideo() {
    if (_isDisposed || !mounted) return;
    if (_videoController != null &&
        VideoPlaybackManager.isPlaying(_videoController!)) {
      AppLogger.info('Pausing video for post: ${widget.post.id}');
      VideoPlaybackManager.pause();
      if (mounted) setState(() {});
    }
  }

  void _togglePlayPause() {
    if (_isDisposed || !mounted) return;
    if (_videoController == null || !_initialized) return;

    final isPlaying = VideoPlaybackManager.isPlaying(_videoController!);
    if (isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // throttle taps when initialized
    final onTapHandler = _initialized
        ? () => Debouncer.instance.throttle(
            'reel_toggle_${widget.post.id}',
            const Duration(milliseconds: 300),
            _togglePlayPause,
          )
        : null;

    return GestureDetector(
      onTap: onTapHandler,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video player or thumbnail
            if (_initialized && _videoController != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              (widget.post.thumbnailUrl != null)
                  ? CachedNetworkImage(
                      imageUrl: widget.post.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 64,
                          color: Colors.white54,
                        ),
                      ),
                    ),

            // If initializing show spinner (higher priority)
            if (_isInitializing)
              const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            // Play icon overlay (only show when NOT initializing and paused)
            else if (!_initialized ||
                (_videoController != null &&
                    !VideoPlaybackManager.isPlaying(_videoController!)))
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 80.0,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing ReelVideoPlayer for post: ${widget.post.id}');
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
