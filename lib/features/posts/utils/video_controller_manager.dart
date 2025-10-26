import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

/// Caches `VideoPlayerController` instances and reference counts them.
/// Adds a simple LRU eviction to bound memory usage on low-end devices.
/// Also dedupes concurrent initializations for the same post id.
class VideoControllerManager {
  VideoControllerManager._({this.maxControllers = 6});
  static VideoControllerManager? _instance;
  factory VideoControllerManager({int maxControllers = 6}) {
    _instance ??= VideoControllerManager._(maxControllers: maxControllers);
    return _instance!;
  }

  final int maxControllers;

  // Controllers keyed by postId
  final Map<String, VideoPlayerController> _controllers = {};
  // Reference counts per postId
  final Map<String, int> _refCounts = {};
  // LRU ordering: front = least recently used, back = most recently used
  final List<String> _lru = [];

  // Ongoing initialization futures to dedupe concurrent getController calls
  final Map<String, Future<VideoPlayerController>> _ongoingInits = {};

  /// Returns a controller for [postId], downloading/caching the [url] if needed.
  /// The returned controller is reference-counted; call [releaseController] when done.
  Future<VideoPlayerController> getController(String postId, String url) async {
    // If present, bump refcount and LRU position
    if (_controllers.containsKey(postId)) {
      _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
      _touchLru(postId);
      return _controllers[postId]!;
    }

    // If an initialization is already in progress for this post, return the same Future
    if (_ongoingInits.containsKey(postId)) {
      try {
        final ctrl = await _ongoingInits[postId]!;
        // ensure we bump refcount if returned successfully
        _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
        _touchLru(postId);
        return ctrl;
      } catch (e) {
        // If the ongoing init failed, remove it and fall through to attempt again
        _ongoingInits.remove(postId);
      }
    }

    // Evict least recently used controllers with refCount == 0 until we have space.
    await _evictIfNeeded();

    // Start initialization and store the future to dedupe
    final initFuture = _initializeController(postId, url);
    _ongoingInits[postId] = initFuture;

    try {
      final controller = await initFuture;
      // Register controller and set ref count
      _controllers[postId] = controller;
      _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
      _touchLru(postId);
      return controller;
    } finally {
      _ongoingInits.remove(postId);
    }
  }

  Future<VideoPlayerController> _initializeController(
    String postId,
    String url,
  ) async {
    // Download or reuse cached file (may throw - caller should handle)
    final File file = await DefaultCacheManager().getSingleFile(url);

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    controller.setLooping(true);
    return controller;
  }

  /// Decrement refcount and dispose controller when count reaches zero.
  void releaseController(String postId) {
    if (!_controllers.containsKey(postId)) return;

    _refCounts[postId] = (_refCounts[postId] ?? 1) - 1;
    if ((_refCounts[postId] ?? 0) <= 0) {
      // Dispose and remove immediately to free memory, and remove from LRU.
      try {
        _controllers[postId]?.dispose();
      } catch (_) {}
      _controllers.remove(postId);
      _refCounts.remove(postId);
      _removeFromLru(postId);
    } else {
      // Still referenced; touch LRU so it's treated as recently used.
      _touchLru(postId);
    }
  }

  /// Force dispose all (call on app shutdown).
  void disposeAll() {
    for (final c in _controllers.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    _refCounts.clear();
    _lru.clear();
    // Cancel any ongoing inits by just clearing references — the underlying futures
    // will still complete, but we won't retain or reuse their controllers.
    _ongoingInits.clear();
  }

  // --- LRU helpers ---

  void _touchLru(String key) {
    _removeFromLru(key);
    _lru.add(key);
  }

  void _removeFromLru(String key) {
    _lru.removeWhere((k) => k == key);
  }

  Future<void> _evictIfNeeded() async {
    // Try to evict until below maxControllers.
    while (_controllers.length >= maxControllers) {
      // Find least recently used with refCount == 0
      final candidate = _lru.firstWhere(
        (k) => (_refCounts[k] ?? 0) <= 0,
        orElse: () => '',
      );

      if (candidate.isEmpty) {
        // No zero-ref candidates — as a last resort, evict the absolute least used controller
        final fallback = _lru.isNotEmpty ? _lru.first : null;
        if (fallback == null) break; // nothing to evict
        try {
          _controllers[fallback]?.dispose();
        } catch (_) {}
        _controllers.remove(fallback);
        _refCounts.remove(fallback);
        _removeFromLru(fallback);
      } else {
        // Dispose candidate and remove
        try {
          _controllers[candidate]?.dispose();
        } catch (_) {}
        _controllers.remove(candidate);
        _refCounts.remove(candidate);
        _removeFromLru(candidate);
      }

      // Yield a microtask to avoid blocking synchronous callers if eviction is heavy
      await Future<void>.delayed(Duration.zero);
    }
  }
}
