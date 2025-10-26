// lib/features/posts/presentation/pages/full_media_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

/// Full screen viewer for both images and videos.
/// Expects PostEntity passed via `extra` in GoRouter (or Navigator).
class FullMediaPage extends StatefulWidget {
  final PostEntity post;

  const FullMediaPage({super.key, required this.post});

  @override
  State<FullMediaPage> createState() => _FullMediaPageState();
}

class _FullMediaPageState extends State<FullMediaPage> {
  final VideoControllerManager _videoManager = VideoControllerManager();
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _isInitializing = false;
  bool _isDisposed = false;

  // Seeking state for slider
  Duration? _scrubValue; // temp value while dragging
  bool _isScrubbing = false;
  bool _wasPlayingBeforeScrub = false;

  @override
  void initState() {
    super.initState();
    if (widget.post.mediaType == 'video') {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    if (_isDisposed || _initialized || _isInitializing) return;
    _isInitializing = true;
    try {
      final ctrl = await _videoManager.getController(
        widget.post.id,
        widget.post.mediaUrl!,
      );
      if (_isDisposed) {
        _videoManager.releaseController(widget.post.id);
        return;
      }

      // attach listener to update UI on position/duration changes
      ctrl.addListener(_videoListener);

      setState(() {
        _videoController = ctrl;
        _initialized = true;
        _isInitializing = false;
      });

      // start playing once ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _videoController != null) {
          VideoPlaybackManager.play(_videoController!, () {
            if (mounted) setState(() {});
          });
        }
      });
    } catch (e) {
      _isInitializing = false;
      // fall back to thumbnail — do nothing else
    }
  }

  void _videoListener() {
    // Only update UI when not scrubbing (we show temporary scrub value during drag)
    if (!mounted || _isScrubbing) return;

    // VideoPlayerController's value frequently updates; keep light-weight
    final value = _videoController?.value;
    if (value == null) return;

    // If buffering or playing/duration changed, refresh UI
    // A simple setState here is fine; it's cheap in this page.
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    if (_videoController == null || !_initialized) return;
    final playing = VideoPlaybackManager.isPlaying(_videoController!);
    if (playing) {
      VideoPlaybackManager.pause();
      setState(() {});
    } else {
      VideoPlaybackManager.play(_videoController!, () {
        if (mounted) setState(() {});
      });
      setState(() {});
    }
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final totalSeconds = d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Called when user starts scrubbing the slider
  void _onScrubStart(double value) {
    if (_videoController == null || !_initialized) return;
    _isScrubbing = true;
    _scrubValue = _videoController!.value.duration * value;
    _wasPlayingBeforeScrub = VideoPlaybackManager.isPlaying(_videoController!);
    if (_wasPlayingBeforeScrub) {
      VideoPlaybackManager.pause();
    }
    setState(() {});
  }

  // While dragging — update visual position only
  void _onScrubUpdate(double value) {
    if (_videoController == null || !_initialized) return;
    _scrubValue = _videoController!.value.duration * value;
    setState(() {});
  }

  // When drag ends — perform actual seek and resume if needed
  void _onScrubEnd(double value) {
    if (_videoController == null || !_initialized) {
      _isScrubbing = false;
      _scrubValue = null;
      return;
    }
    final target = _videoController!.value.duration * value;
    // clamp target
    final safeTarget = Duration(
      milliseconds: target.inMilliseconds.clamp(
        0,
        _videoController!.value.duration.inMilliseconds,
      ),
    );

    // Perform the seek (do it once on drag end)
    _videoController!
        .seekTo(safeTarget)
        .then((_) {
          // resume play if it was playing before scrub
          if (_wasPlayingBeforeScrub) {
            VideoPlaybackManager.play(_videoController!, () {
              if (mounted) setState(() {});
            });
          }
          // clear scrubbing state
          if (mounted) {
            _isScrubbing = false;
            _scrubValue = null;
            setState(() {});
          }
        })
        .catchError((_) {
          // Always clear scrubbing state even on error
          if (mounted) {
            _isScrubbing = false;
            _scrubValue = null;
            setState(() {});
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.post;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Centered hero content for image/video
            Center(
              child: Hero(
                tag: 'media_${media.id}',
                child: media.mediaType == 'image'
                    ? _buildInteractiveImage(media)
                    : _buildFullVideo(media),
              ),
            ),

            // Top-left: back
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
            ),

            // Top-right: play/pause or placeholder (for image we don't show play)
            if (media.mediaType == 'video')
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () => Debouncer.instance.throttle(
                      'full_media_toggle_${media.id}',
                      const Duration(milliseconds: 300),
                      _togglePlayPause,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _videoController != null &&
                                VideoPlaybackManager.isPlaying(
                                  _videoController!,
                                )
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom controls for video: seekbar + time (only for video)
            if (media.mediaType == 'video')
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(child: _buildVideoControls()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveImage(PostEntity media) {
    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 1.0,
      maxScale: 4.0,
      child: CachedNetworkImage(
        imageUrl: media.mediaUrl!,
        fit: BoxFit.contain,
        width: double.infinity,
        placeholder: (context, _) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, _, __) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.white)),
      ),
    );
  }

  Widget _buildFullVideo(PostEntity media) {
    if (!_initialized || _videoController == null) {
      // show thumbnail as fallback while initializing
      return media.thumbnailUrl != null
          ? CachedNetworkImage(
              imageUrl: media.thumbnailUrl!,
              fit: BoxFit.contain,
              width: double.infinity,
            )
          : const Center(
              child: Icon(Icons.play_circle_outline, color: Colors.white),
            );
    }

    // Show video inside AspectRatio so it scales correctly
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: GestureDetector(
        onTap: () => Debouncer.instance.throttle(
          'full_media_toggle_${media.id}',
          const Duration(milliseconds: 300),
          _togglePlayPause,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_videoController!),

            // Show big play icon when paused
            if (!VideoPlaybackManager.isPlaying(_videoController!) &&
                !_isScrubbing)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 80,
                  color: Colors.white,
                ),
              ),

            // Show buffering spinner when controller reports buffering or still initializing
            if (_isInitializing || _videoController!.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    if (_videoController == null || !_initialized) {
      // Minimal controls while initializing
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.black45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(width: 12),
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 12),
            Text('Loading...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    final value = _videoController!.value;
    final duration = value.duration;
    final position = _isScrubbing
        ? _scrubValue ?? Duration.zero
        : value.position;
    final maxMilliseconds = duration.inMilliseconds > 0
        ? duration.inMilliseconds
        : 1;
    final positionFraction =
        (position.inMilliseconds.clamp(0, maxMilliseconds)) / maxMilliseconds;

    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seekbar
          Row(
            children: [
              // Current time
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),

              const SizedBox(width: 8),

              // Slider (expanded)
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: 1.0,
                    value: positionFraction.isFinite
                        ? positionFraction.clamp(0.0, 1.0)
                        : 0.0,
                    onChangeStart: (v) => _onScrubStart(v),
                    onChanged: (v) => _onScrubUpdate(v),
                    onChangeEnd: (v) => _onScrubEnd(v),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Total duration
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Row of small controls: rewind 10s, play/pause, forward 10s
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                  final curr = _videoController!.value.position;
                  final target = curr - const Duration(seconds: 10);
                  _videoController!.seekTo(
                    target >= Duration.zero ? target : Duration.zero,
                  );
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  VideoPlaybackManager.isPlaying(_videoController!)
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () => Debouncer.instance.throttle(
                  'full_media_toggle_${widget.post.id}',
                  const Duration(milliseconds: 300),
                  _togglePlayPause,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                  final curr = _videoController!.value.position;
                  final dur = _videoController!.value.duration;
                  final target = curr + const Duration(seconds: 10);
                  _videoController!.seekTo(target <= dur ? target : dur);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.removeListener(_videoListener);
      if (VideoPlaybackManager.isPlaying(controller)) {
        VideoPlaybackManager.pause(invokeCallback: false);
      }
      _videoManager.releaseController(widget.post.id);
    }
    super.dispose();
  }
}
