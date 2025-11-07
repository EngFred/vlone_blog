import 'dart:async';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';

/// Manages and caches [VideoPlayerController] instances globally.
///
/// This manager uses:
/// 1. **Reference Counting:** Ensures a controller is only disposed when all widgets
/// using it have called [releaseController].
/// 2. **LRU Eviction:** Implements a simple Least Recently Used policy to release
/// unused controllers when the [maxControllers] limit is reached, limiting
/// memory footprint. Only controllers with a reference count of zero are evicted.
/// 3. **Deduplication:** Prevents multiple widgets from concurrently initializing
/// the same video controller.
/// 4. **Caching:** Uses [cached_video_player_plus] to serve video files from the local
/// cache or fall back to network streaming, prioritizing cached files.
/// 5. **Navigation Hold:** Provides a mechanism ([holdForNavigation]) to temporarily
/// keep a controller alive during short route transitions (e.g., Hero animations).
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

  /// Stores active players, keyed by `postId`.
  final Map<String, CachedVideoPlayerPlus> _players = {};

  /// Stores the number of active references for each controller.
  final Map<String, int> _refCounts = {};

  /// Manages the Least Recently Used order. The front is the least recently used,
  /// and the back is the most recently used.
  final List<String> _lru = [];

  /// Stores ongoing initialization futures to deduplicate concurrent requests for the same video.
  final Map<String, Future<CachedVideoPlayerPlus>> _ongoingInits = {};

  /// Stores timers for controllers temporarily held alive during navigation.
  final Map<String, Timer> _holdTimers = {};

  /// Retrieves or initializes a controller for the given [postId] and [url].
  ///
  /// This function automatically increments the reference count. [releaseController]
  /// must be called when the consumer is done with the controller.
  Future<VideoPlayerController> getController(String postId, String url) async {
    // Checking if the player is already loaded.
    if (_players.containsKey(postId)) {
      // Bumping the reference count and updating the LRU position.
      _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
      _touchLru(postId);
      return _players[postId]!.controller;
    }

    // Checking if initialization is already running to avoid duplication.
    if (_ongoingInits.containsKey(postId)) {
      try {
        final player = await _ongoingInits[postId]!;
        // Ensuring the reference count is bumped upon successful return.
        _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
        _touchLru(postId);
        return player.controller;
      } catch (e) {
        // Removing the future if initialization failed, allowing a retry.
        _ongoingInits.remove(postId);
        rethrow;
      }
    }

    // Attempting to evict unreferenced controllers if the limit is exceeded.
    await _evictIfNeeded();

    // Starting the initialization process and storing the future for deduplication.
    final initFuture = _initializePlayer(postId, url);
    _ongoingInits[postId] = initFuture;

    try {
      final player = await initFuture;
      // Registering the successfully initialized player and setting the initial reference count.
      _players[postId] = player;
      _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
      _touchLru(postId);
      return player.controller;
    } finally {
      // Removing the future, whether initialization succeeded or failed.
      _ongoingInits.remove(postId);
    }
  }

  /// Handles the actual creation and initialization of the [CachedVideoPlayerPlus].
  ///
  /// This method uses the cached_video_player_plus package to handle caching automatically.
  Future<CachedVideoPlayerPlus> _initializePlayer(
    String postId,
    String url,
  ) async {
    final player = CachedVideoPlayerPlus.networkUrl(Uri.parse(url));

    try {
      await player.initialize();
      await player.controller.setLooping(true);
      return player;
    } catch (e) {
      // Cleaning up the player on failure.
      player.dispose();
      rethrow;
    }
  }

  /// Decrements the reference count for a given [postId].
  ///
  /// If the reference count drops to zero, the player is immediately disposed and removed.
  void releaseController(String postId) {
    if (!_players.containsKey(postId) && !_refCounts.containsKey(postId)) {
      // Ignoring if the player or ref count is not registered.
      return;
    }

    _refCounts[postId] = (_refCounts[postId] ?? 1) - 1;

    if ((_refCounts[postId] ?? 0) <= 0) {
      // Disposing and removing the player immediately as it is no longer referenced.
      try {
        _players[postId]?.dispose();
      } catch (_) {
        // Ignoring disposal errors.
      }
      _players.remove(postId);
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

  /// Forces the disposal of all managed players and clears all state.
  ///
  /// This method should be called when the application is shutting down.
  void disposeAll() {
    for (final p in _players.values) {
      try {
        p.dispose();
      } catch (_) {
        // Ignoring disposal errors.
      }
    }
    _players.clear();
    _refCounts.clear();
    _lru.clear();

    // Cancelling all pending navigation hold timers.
    for (final t in _holdTimers.values) {
      t.cancel();
    }
    _holdTimers.clear();

    // Clearing ongoing initialization futures. The underlying Future may complete,
    // but the resulting player will not be stored or used.
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

  /// Disposes and removes least recently used players that have a zero reference
  /// count until the total number of players is below [maxControllers].
  Future<void> _evictIfNeeded() async {
    while (_players.length >= maxControllers) {
      // Finding the least recently used player with no active references.
      final candidate = _lru.firstWhere(
        (k) => (_refCounts[k] ?? 0) <= 0,
        orElse: () => '',
      );

      if (candidate.isEmpty) {
        // Exiting if all current players are still referenced (refCount > 0).
        break;
      } else {
        // Disposing and removing the candidate.
        try {
          _players[candidate]?.dispose();
        } catch (_) {
          // Ignoring disposal errors.
        }
        _players.remove(candidate);
        _refCounts.remove(candidate);
        _removeFromLru(candidate);
      }
      // Yielding a microtask to prevent blocking the thread if many evictions are needed.
      await Future<void>.delayed(Duration.zero);
    }
  }
}
