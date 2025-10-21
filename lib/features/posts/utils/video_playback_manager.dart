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
      } catch (e) {
        // Safely ignore if disposed
      }
      // call previous callback but defer it to avoid reentrancy issues
      final previousCallback = _onPauseCallback;
      _onPauseCallback = null;
      if (previousCallback != null) {
        // schedule it for next frame so we don't trigger setState during a locked frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            previousCallback();
          } catch (_) {}
        });
      }
    }
    _controller = controller;
    _onPauseCallback = onPauseCallback;
    try {
      _controller?.play();
    } catch (e) {
      // Safely ignore if disposed
    }
  }

  /// Pause the current controller.
  ///
  /// If [invokeCallback] is true (default) the stored `_onPauseCallback` will be
  /// invoked (deferred to next frame). If false, the callback will be cleared
  /// and not invoked — useful when disposing a widget.
  static void pause({bool invokeCallback = true}) {
    try {
      _controller?.pause();
    } catch (e) {
      // Safely ignore if disposed
    }

    final cb = _onPauseCallback;
    // clear stored references immediately to avoid reentrancy issues
    _onPauseCallback = null;
    _controller = null;

    if (invokeCallback && cb != null) {
      // defer to next frame to avoid calling setState while the framework is locked
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          cb();
        } catch (_) {}
      });
    }
  }

  static bool isPlaying(VideoPlayerController controller) {
    try {
      return _controller == controller && controller.value.isPlaying;
    } catch (e) {
      return false; // Safely handle if controller is disposed or error occurs
    }
  }
}
