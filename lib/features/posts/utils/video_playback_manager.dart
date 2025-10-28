import 'package:video_player/video_player.dart';
import 'package:flutter/widgets.dart';

/// Ensures only one VideoPlayerController is playing at a time.
/// Adds a short suppression mechanism that callers can use to prevent
/// automatic pause behavior during navigation / hero transitions.
class VideoPlaybackManager {
  static VideoPlayerController? _controller;
  static VoidCallback? _onPauseCallback;

  // Suppress visibility-triggered pauses for a short duration.
  // Useful when navigating from a thumbnail to full-screen (hero).
  static bool _pauseSuppressed = false;

  /// Suppress automatic pause handling for [duration].
  /// This schedules a timer to clear suppression after [duration].
  static void suppressPauseFor(Duration duration) {
    _pauseSuppressed = true;
    Future<void>.delayed(duration, () {
      _pauseSuppressed = false;
    });
  }

  /// Whether pause is currently suppressed.
  static bool get pauseSuppressed => _pauseSuppressed;

  static void play(
    VideoPlayerController controller,
    VoidCallback onPauseCallback,
  ) {
    if (_controller != null && _controller != controller) {
      try {
        // If we are switching controllers, pause the previous one.
        _controller?.pause();
      } catch (e) {
        // ignore disposal issues
      }
      // call previous callback but defer it to avoid reentrancy issues
      final previousCallback = _onPauseCallback;
      _onPauseCallback = null;
      if (previousCallback != null) {
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
      // ignore if disposed
    }
  }

  /// Pause the current controller.
  ///
  /// If [invokeCallback] is true (default) the stored `_onPauseCallback` will be
  /// invoked (deferred to next frame). If false, the callback will be cleared
  /// and not invoked — useful when disposing a widget.
  ///
  /// IMPORTANT: When `pauseSuppressed == true` callers (e.g. VisibilityDetector)
  /// should **not** call this method; instead check `VideoPlaybackManager.pauseSuppressed`
  /// and skip pausing while suppressed.
  static void pause({bool invokeCallback = true}) {
    try {
      _controller?.pause();
    } catch (e) {
      // ignore
    }

    final cb = _onPauseCallback;
    _onPauseCallback = null;
    _controller = null;

    if (invokeCallback && cb != null) {
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
      return false;
    }
  }
}
