import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

/// ReelVideoPlayer
/// - supports single tap toggle (play/pause)
/// - supports double-tap to like (fires a callback provided by parent)
/// - plays an internal heart animation for double-tap (no parent rebuild)
class ReelVideoPlayer extends StatefulWidget {
  final PostEntity post;
  final bool isActive;
  final bool shouldPreload;
  final VoidCallback?
  onDoubleTap; // Notify parent (e.g., ReelItem) to perform like action

  const ReelVideoPlayer({
    super.key,
    required this.post,
    required this.isActive,
    this.shouldPreload = false,
    this.onDoubleTap,
  });

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _isDisposed = false;
  bool _isInitializing = false;
  final VideoControllerManager _videoManager = VideoControllerManager();

  // Heart animation for double-tap
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  Timer? _hideHeartTimer;
  bool _showHeart = false;

  // Small guard to prevent repeated double-tap actions in quick succession.
  // We keep it local and short (safe single-source debounce).
  DateTime? _lastDoubleTapAt;
  static const Duration _doubleTapCooldown = Duration(milliseconds: 700);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.6,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.12,
          end: 0.98,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_heartController);

    _heartOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    if (widget.isActive || widget.shouldPreload) {
      _initializeIfNeeded();
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

  // Trigger heart animation and call parent callback
  void _onDoubleTap() {
    final now = DateTime.now();
    if (_lastDoubleTapAt != null &&
        now.difference(_lastDoubleTapAt!) < _doubleTapCooldown) {
      AppLogger.info(
        'Double-tap ignored due to cooldown for post: ${widget.post.id}',
      );
      return;
    }
    _lastDoubleTapAt = now;

    // Animate heart (local)
    if (_hideHeartTimer != null) {
      _hideHeartTimer!.cancel();
      _hideHeartTimer = null;
    }
    setState(() => _showHeart = true);
    _heartController
      ..reset()
      ..forward();

    // ensure it hides after animation
    _hideHeartTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });

    // Haptic
    HapticFeedback.mediumImpact();

    // Notify parent to perform like action (parent should NOT re-debounce)
    try {
      widget.onDoubleTap?.call();
    } catch (e, st) {
      AppLogger.error(
        'onDoubleTap callback threw: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  Widget _buildPlayPauseOverlay() {
    final isPlaying =
        _videoController != null &&
        _initialized &&
        VideoPlaybackManager.isPlaying(_videoController!);

    return AnimatedOpacity(
      opacity: isPlaying ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
            ),
            child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final onTapHandler = _initialized
        ? () => Debouncer.instance.throttle(
            'reel_toggle_${widget.post.id}',
            const Duration(milliseconds: 300),
            _togglePlayPause,
          )
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTapHandler,
      onDoubleTap: _onDoubleTap,
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
            else if (widget.post.thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: widget.post.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[900],
                  child: const Center(child: LoadingIndicator(size: 24)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(
                    Icons.videocam_outlined,
                    size: 64,
                    color: Colors.white54,
                  ),
                ),
              ),

            // Loading indicator
            if (_isInitializing)
              const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),

            // Play/pause overlay
            if (_initialized && _videoController != null)
              _buildPlayPauseOverlay(),

            // Heart double-tap animation (center)
            if (_showHeart)
              Center(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _heartController,
                    builder: (context, child) {
                      final scale = _heartScale.value;
                      final opacity = _heartOpacity.value;
                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.15),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.favorite,
                        size: 96,
                        color: Colors.white.withOpacity(0.95),
                        shadows: [
                          const Shadow(
                            blurRadius: 12,
                            color: Colors.black45,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (!_initialized && !_isInitializing) {
          _initializeIfNeeded().then((_) {
            if (mounted && widget.isActive) _playVideo();
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

  @override
  void dispose() {
    AppLogger.info('Disposing ReelVideoPlayer for post: ${widget.post.id}');
    _isDisposed = true;
    _hideHeartTimer?.cancel();
    _heartController.dispose();
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
