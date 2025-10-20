import 'package:video_player/video_player.dart';
import 'package:flutter/widgets.dart';

/// Ensures only one VideoPlayerController is playing at a time.
class VideoPlaybackManager {
  static VideoPlayerController? _controller;
  static VoidCallback? _onPauseCallback;

  static void play(
    VideoPlayerController controller,
    VoidCallback onPauseCallback,
  ) {
    if (_controller != null && _controller != controller) {
      try {
        _controller?.pause();
      } catch (_) {}
      _onPauseCallback?.call();
    }
    _controller = controller;
    _onPauseCallback = onPauseCallback;
    try {
      _controller?.play();
    } catch (_) {}
  }

  static void pause() {
    try {
      _controller?.pause();
    } catch (_) {}
    _onPauseCallback?.call();
    _controller = null;
    _onPauseCallback = null;
  }

  static bool isPlaying(VideoPlayerController controller) {
    try {
      return _controller == controller && controller.value.isPlaying;
    } catch (_) {
      return false; // Safely handle if controller is disposed or error occurs
    }
  }
}
