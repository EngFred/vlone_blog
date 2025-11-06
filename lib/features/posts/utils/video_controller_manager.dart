import 'dart:async';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

/// Manages and caches [VideoPlayerController] instances globally.
///
/// This manager uses:
/// 1. **Reference Counting:** Ensures a controller is only disposed when all widgets
///    using it have called [releaseController].
/// 2. **LRU Eviction:** Implements a simple Least Recently Used policy to release
///    unused controllers when the [maxControllers] limit is reached, limiting
///    memory footprint. Only controllers with a reference count of zero are evicted.
/// 3. **Deduplication:** Prevents multiple widgets from concurrently initializing
///    the same video controller.
/// 4. **Caching:** Uses [flutter_cache_manager] to serve video files from the local
///    cache or fall back to network streaming, prioritizing cached files.
/// 5. **Navigation Hold:** Provides a mechanism ([holdForNavigation]) to temporarily
///    keep a controller alive during short route transitions (e.g., Hero animations).
class VideoControllerManager {
  /// The maximum number of controllers the manager will keep in memory.
  final int maxControllers;

  // Private constructor for the Singleton pattern.
  VideoControllerManager._({this.maxControllers = 20});

  static VideoControllerManager? _instance;

  /// Provides the Singleton instance of the manager.
  factory VideoControllerManager({int maxControllers = 20}) {
    // Ensuring the manager is instantiated only once.
    _instance ??= VideoControllerManager._(maxControllers: maxControllers);
    return _instance!;
  }

  /// Stores active controllers, keyed by `postId`.
  final Map<String, VideoPlayerController> _controllers = {};

  /// Stores the number of active references for each controller.
  final Map<String, int> _refCounts = {};

  /// Manages the Least Recently Used order. The front is the least recently used,
  /// and the back is the most recently used.
  final List<String> _lru = [];

  /// Stores ongoing initialization futures to deduplicate concurrent requests for the same video.
  final Map<String, Future<VideoPlayerController>> _ongoingInits = {};

  /// Stores timers for controllers temporarily held alive during navigation.
  final Map<String, Timer> _holdTimers = {};

  /// Retrieves or initializes a controller for the given [postId] and [url].
  ///
  /// This function automatically increments the reference count. [releaseController]
  /// must be called when the consumer is done with the controller.
  Future<VideoPlayerController> getController(String postId, String url) async {
    // Checking if the controller is already loaded.
    if (_controllers.containsKey(postId)) {
      // Bumping the reference count and updating the LRU position.
      _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
      _touchLru(postId);
      return _controllers[postId]!;
    }

    // Checking if initialization is already running to avoid duplication.
    if (_ongoingInits.containsKey(postId)) {
      try {
        final ctrl = await _ongoingInits[postId]!;
        // Ensuring the reference count is bumped upon successful return.
        _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
        _touchLru(postId);
        return ctrl;
      } catch (e) {
        // Removing the future if initialization failed, allowing a retry.
        _ongoingInits.remove(postId);
        rethrow;
      }
    }

    // Attempting to evict unreferenced controllers if the limit is exceeded.
    await _evictIfNeeded();

    // Starting the initialization process and storing the future for deduplication.
    final initFuture = _initializeController(postId, url);
    _ongoingInits[postId] = initFuture;

    try {
      final controller = await initFuture;
      // Registering the successfully initialized controller and setting the initial reference count.
      _controllers[postId] = controller;
      _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
      _touchLru(postId);
      return controller;
    } finally {
      // Removing the future, whether initialization succeeded or failed.
      _ongoingInits.remove(postId);
    }
  }

  /// Handles the actual creation and initialization of the [VideoPlayerController].
  ///
  /// This method checks the cache before falling back to a network URL.
  Future<VideoPlayerController> _initializeController(
    String postId,
    String url,
  ) async {
    VideoPlayerController controller;
    final cacheManager = DefaultCacheManager();

    // Attempting to retrieve the file from the local cache.
    final fileInfo = await cacheManager.getFileFromCache(url);

    if (fileInfo != null && fileInfo.file.existsSync()) {
      // Using the local file if it is cached, enabling instant playback.
      controller = VideoPlayerController.file(fileInfo.file);
    } else {
      // Using a network controller for progressive streaming if not cached.
      controller = VideoPlayerController.networkUrl(Uri.parse(url));

      // Triggering background caching for future use (fire-and-forget).
      cacheManager
          .downloadFile(url)
          .then<void>(
            (_) {},
            onError: (_) {
              // Silently handling caching errors to avoid impacting current playback.
            },
          );
    }

    try {
      await controller.initialize();
      controller.setLooping(true);
      return controller;
    } catch (e) {
      // Cleaning up the controller on failure.
      controller.dispose();
      rethrow;
    }
  }

  /// Decrements the reference count for a given [postId].
  ///
  /// If the reference count drops to zero, the controller is immediately disposed and removed.
  void releaseController(String postId) {
    if (!_controllers.containsKey(postId) && !_refCounts.containsKey(postId)) {
      // Ignoring if the controller or ref count is not registered.
      return;
    }

    _refCounts[postId] = (_refCounts[postId] ?? 1) - 1;

    if ((_refCounts[postId] ?? 0) <= 0) {
      // Disposing and removing the controller immediately as it is no longer referenced.
      try {
        _controllers[postId]?.dispose();
      } catch (_) {
        // Ignoring disposal errors.
      }
      _controllers.remove(postId);
      _refCounts.remove(postId);
      _removeFromLru(postId);
    } else {
      // Touching LRU to signify it was recently interacted with (still referenced).
      _touchLru(postId);
    }
  }

  /// Temporarily prevents a controller from being released when its consuming widget
  /// is disposed, useful for route/hero transitions.
  ///
  /// This function increases the reference count and schedules a timer to release
  /// that synthetic hold after the specified time-to-live ([ttl]).
  void holdForNavigation(String postId, Duration ttl) {
    // Cancelling any existing hold timer to reset the TTL.
    _holdTimers[postId]?.cancel();

    // Bumping a synthetic refcount to prevent disposal while the hold is active.
    _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
    _touchLru(postId);

    // Scheduling a timer to release the synthetic hold when the TTL expires.
    _holdTimers[postId] = Timer(ttl, () {
      _holdTimers.remove(postId);
      // Releasing the synthetic reference.
      releaseController(postId);
    });
  }

  /// Forces the disposal of all managed controllers and clears all state.
  ///
  /// This method should be called when the application is shutting down.
  void disposeAll() {
    for (final c in _controllers.values) {
      try {
        c.dispose();
      } catch (_) {
        // Ignoring disposal errors.
      }
    }
    _controllers.clear();
    _refCounts.clear();
    _lru.clear();

    // Cancelling all pending navigation hold timers.
    for (final t in _holdTimers.values) {
      t.cancel();
    }
    _holdTimers.clear();

    // Clearing ongoing initialization futures. The underlying Future may complete,
    // but the resulting controller will not be stored or used.
    _ongoingInits.clear();
  }

  // --- LRU Internal Helpers ---

  /// Moves the key to the most recently used position (back of the list).
  void _touchLru(String key) {
    _removeFromLru(key);
    _lru.add(key);
  }

  /// Removes the key from the LRU list.
  void _removeFromLru(String key) {
    _lru.removeWhere((k) => k == key);
  }

  /// Disposes and removes least recently used controllers that have a zero reference
  /// count until the total number of controllers is below [maxControllers].
  Future<void> _evictIfNeeded() async {
    while (_controllers.length >= maxControllers) {
      // Finding the least recently used controller with no active references.
      final candidate = _lru.firstWhere(
        (k) => (_refCounts[k] ?? 0) <= 0,
        orElse: () => '',
      );

      if (candidate.isEmpty) {
        // Exiting if all current controllers are still referenced (refCount > 0).
        break;
      } else {
        // Disposing and removing the candidate.
        try {
          _controllers[candidate]?.dispose();
        } catch (_) {
          // Ignoring disposal errors.
        }
        _controllers.remove(candidate);
        _refCounts.remove(candidate);
        _removeFromLru(candidate);
      }
      // Yielding a microtask to prevent blocking the thread if many evictions are needed.
      await Future<void>.delayed(Duration.zero);
    }
  }
}
