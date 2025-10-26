import 'dart:async';

import 'package:flutter/material.dart';

/// A small singleton debouncer keyed by a string action key.
/// Use this when you want to ignore rapid repeated taps for a specific action.
/// It supports both debounce (trailing-edge) and throttle (leading-edge).
class Debouncer {
  Debouncer._();
  static final Debouncer instance = Debouncer._();

  final Map<String, Timer> _timers = {};
  final Map<String, DateTime> _lastExecuted = {};

  /// Debounce an action identified by [key]. If another call with the same key
  /// happens before [duration] elapses, the previous scheduled action is cancelled.
  /// The action executes after [duration] of *inactivity*.
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
      // Best-effort fallback: execute immediately if timer errors
      action();
      _timers.remove(key);
      _lastExecuted[key] = DateTime.now();
    }
  }

  /// Throttle an action identified by [key]. The action is executed immediately
  /// if the last execution was before [duration] ago. Otherwise the call is ignored.
  /// This is the preferred behavior for play/pause and navigation taps.
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
    // If within throttle window, ignore the call.
  }

  /// Cancel any pending debounced action for [key].
  void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _lastExecuted.remove(key);
  }

  /// Cancel all pending actions. Useful when logging out or resetting app state.
  void cancelAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _lastExecuted.clear();
  }

  /// Returns true if there is a pending action for [key].
  bool isPending(String key) => _timers.containsKey(key);
}
