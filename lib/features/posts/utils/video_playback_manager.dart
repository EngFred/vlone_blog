import 'package:video_player/video_player.dart';
import 'package:flutter/widgets.dart';

/// Manages the global playback state to enforce a single active video player.
///
/// This singleton utility ensures that when one video starts playing, any previously
/// playing video is automatically paused. It also provides a mechanism to suppress
/// external pause triggers (like [VisibilityDetector]) during transitions.
class VideoPlaybackManager {
  /// The single video controller that is currently active and playing.
  static VideoPlayerController? _controller;

  /// The callback associated with the currently playing controller, invoked when it pauses.
  static VoidCallback? _onPauseCallback;

  /// A flag indicating if automatic pause logic (e.g., from visibility detection)
  /// should be temporarily ignored.
  static bool _pauseSuppressed = false;

  /// Temporarily suppresses automatic pause behavior for the specified [duration].
  ///
  /// This is essential during hero or route transitions to prevent the source widget's
  /// disposal or visibility change from pausing the video prematurely.
  static void suppressPauseFor(Duration duration) {
    _pauseSuppressed = true;
    Future<void>.delayed(duration, () {
      _pauseSuppressed = false;
    });
  }

  /// Reports whether automatic pause is currently being suppressed.
  static bool get pauseSuppressed => _pauseSuppressed;

  /// Sets the given [controller] as the actively playing video and starts playback.
  ///
  /// If another video is currently playing, it is paused first. The [onPauseCallback]
  /// is stored to be invoked when this controller is eventually paused.
  static void play(
    VideoPlayerController controller,
    VoidCallback onPauseCallback,
  ) {
    if (_controller != null && _controller != controller) {
      try {
        // Pausing the previous controller when switching active videos.
        _controller?.pause();
      } catch (e) {
        // Ignoring potential disposal issues on the old controller.
      }
      // Storing the previous callback and deferring its execution to the next frame
      // to avoid reentrancy issues within the current frame's build/layout phase.
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
      // Ignoring if the controller was disposed externally.
    }
  }

  /// Pauses the currently active controller.
  ///
  /// - If [invokeCallback] is true (default), the stored `_onPauseCallback` is
  ///   invoked (deferred to the next frame).
  /// - If [invokeCallback] is false, the callback is cleared without invocation.
  ///   This is useful when the widget owning the callback is disposing.
  ///
  /// Consumers (like [VisibilityDetector]) should check [pauseSuppressed] before
  /// calling this method to skip pausing during navigation transitions.
  static void pause({bool invokeCallback = true}) {
    try {
      _controller?.pause();
    } catch (e) {
      // Ignoring potential disposal errors.
    }

    final cb = _onPauseCallback;
    // Clearing the global state immediately upon pause.
    _onPauseCallback = null;
    _controller = null;

    if (invokeCallback && cb != null) {
      // Deferring the callback execution to the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          cb();
        } catch (_) {}
      });
    }
  }

  /// Reports whether the given [controller] is the currently active and playing controller.
  static bool isPlaying(VideoPlayerController controller) {
    try {
      // Checking both for state equality and the controller's internal playback status.
      return _controller == controller && controller.value.isPlaying;
    } catch (e) {
      // Returning false if the controller is disposed or in an invalid state.
      return false;
    }
  }
}
