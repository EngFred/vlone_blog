import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

/// Dedicated video player for reels with proper lifecycle management
/// Handles immediate autoplay and smooth preloading
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
    //Only initialize if active or should preload, but don't auto-play yet
    if (widget.isActive || widget.shouldPreload) {
      _initializeIfNeeded();
    }
  }

  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle active state changes
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        // Initialize first if needed, then play
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

    // Handle preload changes
    if (widget.shouldPreload != oldWidget.shouldPreload) {
      if (widget.shouldPreload && !_initialized && !_isInitializing) {
        _initializeIfNeeded();
      }
    }
  }

  Future<void> _initializeIfNeeded() async {
    if (_isDisposed || !mounted) return;
    if (_initialized || _videoController != null) return;
    if (_isInitializing) return; //Prevent concurrent initialization

    // Only initialize if active or should preload
    if (!widget.isActive && !widget.shouldPreload) return;

    _isInitializing = true; // Lock to prevent race condition
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

        //Only auto-play if this is the active reel AND we're not already playing
        if (widget.isActive &&
            mounted &&
            !VideoPlaybackManager.isPlaying(controller)) {
          // Small delay to ensure UI is ready
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
      // Silently fail to thumbnail
    }
  }

  void _playVideo() {
    if (_isDisposed || !mounted) return;

    if (!_initialized && _videoController == null) {
      // Don't initialize here to avoid double init
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

    return GestureDetector(
      onTap: _initialized ? _togglePlayPause : null,
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
              // Show thumbnail while loading
              widget.post.thumbnailUrl != null
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

            // Play icon overlay (only show when paused)
            if (!_initialized ||
                (_videoController != null &&
                    !VideoPlaybackManager.isPlaying(_videoController!)))
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 80.0,
                  color: Colors.white,
                ),
              ),

            // Loading indicator during initialization
            if (_isInitializing && widget.isActive)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
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
