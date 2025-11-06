import 'dart:async';

import 'package:flutter/material.dart';

/// A singleton utility class providing methods for both debouncing (trailing-edge)
/// and throttling (leading-edge) user actions.
///
/// Actions are uniquely identified and managed by a string key, allowing independent
/// control over different simultaneous operations (e.g., search debounce vs. button throttle).
class Debouncer {
  Debouncer._();
  static final Debouncer instance = Debouncer._();

  // Stores active timers for debounced actions.
  final Map<String, Timer> _timers = {};
  // Stores the last execution time for throttled actions.
  final Map<String, DateTime> _lastExecuted = {};

  /// Debounces an action identified by [key].
  ///
  /// If this function is called multiple times within the specified [duration],
  /// the previously scheduled action is cancelled. The [action] is executed
  /// only after a period of [duration] has passed without any new calls for the same [key].
  void debounce(String key, Duration duration, VoidCallback action) {
    try {
      _timers[key]?.cancel();
      _timers[key] = Timer(duration, () {
        try {
          action();
        } finally {
          _timers.remove(key);
          _lastExecuted[key] = DateTime.now();
        }
      });
    } catch (_) {
      // Best-effort fallback: executing immediately if an error occurs during timer creation/management.
      action();
      _timers.remove(key);
      _lastExecuted[key] = DateTime.now();
    }
  }

  /// Throttles an action identified by [key].
  ///
  /// The [action] is executed immediately upon the first call. Subsequent calls
  /// within the [duration] period are ignored. This is ideal for limiting the
  /// frequency of high-frequency events like button taps or scrolling handlers.
  void throttle(String key, Duration duration, VoidCallback action) {
    final now = DateTime.now();
    final last = _lastExecuted[key];
    if (last == null || now.difference(last) >= duration) {
      try {
        action();
      } finally {
        _lastExecuted[key] = DateTime.now();
      }
    }
    // If the call is within the throttle window, it is silently ignored.
  }

  /// Cancels any debounced action that is currently pending for the given [key].
  void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _lastExecuted.remove(key);
  }

  /// Cancels all pending debounced actions across all keys.
  /// This is typically used during application shutdown or state reset.
  void cancelAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _lastExecuted.clear();
  }

  /// Returns true if an action for [key] is currently waiting to be debounced.
  bool isPending(String key) => _timers.containsKey(key);
}
