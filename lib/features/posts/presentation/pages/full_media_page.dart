import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/service/media_download_service.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

class FullMediaPage extends StatefulWidget {
  final PostEntity post;
  final String? heroTag;

  const FullMediaPage({super.key, required this.post, this.heroTag});

  @override
  State<FullMediaPage> createState() => _FullMediaPageState();
}

class _FullMediaPageState extends State<FullMediaPage> {
  final VideoControllerManager _videoManager = VideoControllerManager();
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _isInitializing = false;
  bool _isDisposed = false;
  Duration? _scrubValue;
  bool _isScrubbing = false;
  bool _wasPlayingBeforeScrub = false;

  final MediaDownloadService _downloadService = sl<MediaDownloadService>();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // --- NEW: State for mute ---
  // Default to unmuted on this page
  bool _isMuted = false;

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

      // --- MODIFIED: Set volume on init ---
      // Ensure it's unmuted (or respects state) when loading
      await ctrl.setVolume(_isMuted ? 0.0 : 1.0);

      ctrl.addListener(_videoListener);
      setState(() {
        _videoController = ctrl;
        _initialized = true;
        _isInitializing = false;
      });
    } catch (e) {
      _isInitializing = false;
    }
  }

  void _videoListener() {
    if (!mounted || _isScrubbing) return;
    final value = _videoController?.value;
    if (value == null) return;
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    if (_videoController == null || !_initialized) return;
    final playing = VideoPlaybackManager.isPlaying(_videoController!);
    if (playing) {
      VideoPlaybackManager.pause();
      setState(() {});
    } else {
      // --- MODIFIED: Set volume on play ---
      // Ensure volume is correct when playback starts
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);

      VideoPlaybackManager.play(_videoController!, () {
        if (mounted) setState(() {});
      });
      setState(() {});
    }
  }

  // --- NEW: Mute toggle function ---
  void _toggleMute() {
    if (_videoController == null || !_initialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
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

  // ---Download handler (unchanged) ---
  Future<void> _handleDownload() async {
    if (_isDownloading) return;

    // Added null check guard clauses for robustness
    if (widget.post.mediaUrl == null || widget.post.mediaType == null) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Error: Media URL or Type is missing.',
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final result = await _downloadService.downloadAndSaveMedia(
      widget.post.mediaUrl!,
      widget.post.mediaType!,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          if (mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        }
      },
    );

    if (!mounted) return;

    setState(() {
      _isDownloading = false;
    });

    // 👇 Reworked feedback using the extended SnackbarUtils
    switch (result.status) {
      case DownloadResultStatus.success:
        SnackbarUtils.showSuccess(context, 'Media saved to gallery!');
        break;

      case DownloadResultStatus.failure:
        SnackbarUtils.showError(
          context,
          result.message ?? 'Download failed. Please try again.',
        );
        break;

      case DownloadResultStatus.permissionDenied:
        SnackbarUtils.showWarning(
          context,
          'Storage permission is required to save media.',
        );
        break;

      case DownloadResultStatus.permissionPermanentlyDenied:
        // Now using showWarning with the custom action!
        SnackbarUtils.showWarning(
          context,
          'Permission denied. Please enable storage access in app settings.',
          action: SnackBarAction(
            label: 'SETTINGS',
            textColor: Colors.white,
            onPressed: openAppSettings, // Function from permission_handler
          ),
        );
        break;
    }
  }

  // --- Download button widget (unchanged) ---
  Widget _buildDownloadButton() {
    if (_isDownloading) {
      return Padding(
        padding: const EdgeInsets.all(8.0), // Match IconButton tap area
        child: SizedBox(
          width: 24, // Icon size
          height: 24, // Icon size
          child: CircularProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_rounded, color: Colors.white),
      onPressed: _handleDownload,
    );
  }

  // --- (All scrubbing methods remain unchanged) ---
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

  void _onScrubUpdate(double value) {
    // ... (no changes)
    if (_videoController == null || !_initialized) return;
    _scrubValue = _videoController!.value.duration * value;
    setState(() {});
  }

  void _onScrubEnd(double value) {
    if (_videoController == null || !_initialized) {
      _isScrubbing = false;
      _scrubValue = null;
      return;
    }
    final target = _videoController!.value.duration * value;
    final safeTarget = Duration(
      milliseconds: target.inMilliseconds.clamp(
        0,
        _videoController!.value.duration.inMilliseconds,
      ),
    );
    _videoController!
        .seekTo(safeTarget)
        .then((_) {
          if (_wasPlayingBeforeScrub) {
            VideoPlaybackManager.play(_videoController!, () {
              if (mounted) setState(() {});
            });
          }
          if (mounted) {
            _isScrubbing = false;
            _scrubValue = null;
            setState(() {});
          }
        })
        .catchError((_) {
          if (mounted) {
            _isScrubbing = false;
            _scrubValue = null;
            setState(() {});
          }
        });
  }

  // --- build() (unchanged) ---
  @override
  Widget build(BuildContext context) {
    final media = widget.post;
    final heroTag = widget.heroTag ?? 'media_${media.id}';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: heroTag,
                child: media.mediaType == 'image'
                    ? _buildInteractiveImage(media)
                    : _buildFullVideo(media),
              ),
            ),
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
            // --- ADDED: Download Button Positioned ---
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(child: _buildDownloadButton()),
            ),
            // Bottom controls (video only)
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

  // --- _buildInteractiveImage() (unchanged) ---
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

  // --- _buildFullVideo() (unchanged) ---
  Widget _buildFullVideo(PostEntity media) {
    if (!_initialized || _videoController == null) {
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
            // Large central play icon when paused
            if (!VideoPlaybackManager.isPlaying(_videoController!) &&
                !_isScrubbing)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            // Buffering indicator
            if (_isInitializing || _videoController!.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED: _buildVideoControls() ---
  Widget _buildVideoControls() {
    if (_videoController == null || !_initialized) {
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
          // Time + seekbar row
          Row(
            children: [
              // Current time
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 8),
              // Slider
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
          // const SizedBox(height: 6), // Removed to make controls more compact
          // Play/pause and Mute controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mute/Unmute Button
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _toggleMute,
              ),

              // Play/Pause Button
              IconButton(
                icon: Icon(
                  VideoPlaybackManager.isPlaying(_videoController!)
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 42, // Made larger to be the primary control
                ),
                onPressed: () => Debouncer.instance.throttle(
                  'full_media_toggle_${widget.post.id}',
                  const Duration(milliseconds: 300),
                  _togglePlayPause,
                ),
              ),

              // Empty Sized Box for spacing to balance the row
              const SizedBox(width: 48), // approx width of an IconButton
            ],
          ),
        ],
      ),
    );
  }

  // --- dispose() (unchanged) ---
  @override
  void dispose() {
    _isDisposed = true;
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.removeListener(_videoListener);
      // if (VideoPlaybackManager.isPlaying(controller)) {
      //   VideoPlaybackManager.pause(invokeCallback: false);
      // }
      _videoManager.releaseController(widget.post.id);
    }
    super.dispose();
  }
}
