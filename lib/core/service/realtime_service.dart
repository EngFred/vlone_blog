import 'dart:async';

import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/stream_comments_usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/stream_favorites_usecase.dart';
import 'package:vlone_blog_app/features/likes/domain/usecases/stream_likes_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/stream_post_deletions_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/stream_posts_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/stream_profile_updates_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_notifications_stream_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_unread_count_stream_usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/domain/usecases/stream_new_users_usecase.dart';

/// A central service managing all global, application-wide real-time data streams
/// sourced from the backend. It uses [StreamController]s to broadcast events
/// to multiple parts of the application (e.g., UI, bloc/cubit layers).
class RealtimeService {
  // --- Use Case Dependencies (Injected for data retrieval) ---
  final StreamNewPostsUseCase streamNewPostsUseCase;
  final StreamPostUpdatesUseCase streamPostUpdatesUseCase;
  final StreamPostDeletionsUseCase streamPostDeletionsUseCase;
  final StreamLikesUseCase streamLikesUseCase;
  final StreamFavoritesUseCase streamFavoritesUseCase;
  final StreamProfileUpdatesUseCase streamProfileUpdatesUseCase;
  final GetNotificationsStreamUseCase streamNotificationsUseCase;
  final GetUnreadCountStreamUseCase streamUnreadCountUseCase;
  final StreamCommentsUseCase streamCommentsUseCase;
  final StreamNewUsersUseCase streamNewUsersUseCase;

  // --- Broadcast Stream Controllers ---
  final StreamController<PostEntity> _newPostController =
      StreamController<PostEntity>.broadcast();
  final StreamController<Map<String, dynamic>> _postUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _postDeletedController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _likesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _favoritesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _profileUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<NotificationEntity>> _notificationsController =
      StreamController<List<NotificationEntity>>.broadcast();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  final StreamController<Map<String, dynamic>> _commentsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<UserListEntity> _newUserController =
      StreamController<UserListEntity>.broadcast();

  // --- Backing Subscriptions (Handles the connection to the Use Cases) ---
  StreamSubscription? _newPostsSub;
  StreamSubscription? _postUpdatesSub;
  StreamSubscription? _postDeletionsSub;
  StreamSubscription? _likesSub;
  StreamSubscription? _favoritesSub;
  StreamSubscription? _profileUpdatesSub;
  StreamSubscription? _notificationsSub;
  StreamSubscription? _unreadCountSub;
  StreamSubscription? _commentsSub;
  StreamSubscription? _newUsersSub;

  // Map for tracking additional profile subscriptions (for users other than the current one).
  final Map<String, StreamSubscription?> _additionalProfileSubs = {};

  bool _isStarted = false;
  String? _currentUserId;

  RealtimeService({
    required this.streamNewPostsUseCase,
    required this.streamPostUpdatesUseCase,
    required this.streamPostDeletionsUseCase,
    required this.streamLikesUseCase,
    required this.streamFavoritesUseCase,
    required this.streamProfileUpdatesUseCase,
    required this.streamNotificationsUseCase,
    required this.streamUnreadCountUseCase,
    required this.streamCommentsUseCase,
    required this.streamNewUsersUseCase,
  });

  // --- Public Broadcast Streams (Exposed for consumers) ---
  Stream<PostEntity> get onNewPost => _newPostController.stream;
  Stream<Map<String, dynamic>> get onPostUpdate =>
      _postUpdatesController.stream;
  Stream<String> get onPostDeleted => _postDeletedController.stream;
  Stream<Map<String, dynamic>> get onLike => _likesController.stream;
  Stream<Map<String, dynamic>> get onFavorite => _favoritesController.stream;
  Stream<Map<String, dynamic>> get onProfileUpdate =>
      _profileUpdatesController.stream;
  Stream<List<NotificationEntity>> get onNotificationsBatch =>
      _notificationsController.stream;
  Stream<int> get onUnreadCount => _unreadCountController.stream;
  Stream<Map<String, dynamic>> get onComment => _commentsController.stream;
  Stream<UserListEntity> get onNewUser => _newUserController.stream;

  bool get isStarted => _isStarted;
  String? get currentUserId => _currentUserId;

  /// Checks if any of the core streams have active listeners, indicating application health.
  bool get areStreamsHealthy {
    return _newPostController.hasListener ||
        _postUpdatesController.hasListener ||
        _postDeletedController.hasListener ||
        _likesController.hasListener ||
        _favoritesController.hasListener;
  }

  /// Initiates all backend subscriptions for the provided [userId].
  ///
  /// This method is **idempotent**: calling it multiple times for the same user is safe.
  /// If called for a different user, it gracefully stops the old streams first.
  Future<void> start(String userId) async {
    if (_isStarted && _currentUserId == userId) {
      AppLogger.info('RealtimeService already started for user $userId');
      return;
    }

    AppLogger.info('RealtimeService starting for user $userId');

    // Stopping existing streams if the service is starting for a different user.
    if (_isStarted && _currentUserId != userId) {
      await stop();
    }

    _currentUserId = userId;

    try {
      // --------------------
      // Starting Posts streams (New, Updates, Deletions)
      // --------------------
      AppLogger.info('RealtimeService: Starting posts streams');

      _newPostsSub = streamNewPostsUseCase(NoParams()).listen(
        (either) => either.fold(
          (failure) =>
              AppLogger.error('Realtime new post failure: ${failure.message}'),
          (post) {
            if (!_newPostController.isClosed) {
              _newPostController.add(post);
              AppLogger.info('RealtimeService: New post emitted: ${post.id}');
            }
          },
        ),
        onError: (err) =>
            AppLogger.error('New posts stream error: $err', error: err),
      );

      _postUpdatesSub = streamPostUpdatesUseCase(NoParams()).listen(
        (either) => either.fold(
          (failure) => AppLogger.error(
            'Realtime post update failure: ${failure.message}',
          ),
          (updateData) {
            if (!_postUpdatesController.isClosed) {
              _postUpdatesController.add(Map<String, dynamic>.from(updateData));
              AppLogger.info(
                'RealtimeService: Post update emitted for: ${updateData['id']}',
              );
            }
          },
        ),
        onError: (err) =>
            AppLogger.error('Post updates stream error: $err', error: err),
      );

      _postDeletionsSub = streamPostDeletionsUseCase(NoParams()).listen(
        (either) => either.fold(
          (failure) => AppLogger.error(
            'Realtime post deletion failure: ${failure.message}',
          ),
          (postId) {
            if (!_postDeletedController.isClosed) {
              _postDeletedController.add(postId);
              AppLogger.info('RealtimeService: Post deletion emitted: $postId');
            }
          },
        ),
        onError: (err) =>
            AppLogger.error('Post deletions stream error: $err', error: err),
      );

      // --------------------
      // Starting Likes & Favorites streams
      // --------------------
      AppLogger.info('RealtimeService: Starting likes and favorites streams');

      _likesSub = streamLikesUseCase(NoParams()).listen(
        (either) => either.fold(
          (failure) =>
              AppLogger.error('Realtime likes failure: ${failure.message}'),
          (likeData) {
            if (!_likesController.isClosed) {
              _likesController.add(Map<String, dynamic>.from(likeData));
            }
          },
        ),
        onError: (err) =>
            AppLogger.error('Likes stream error: $err', error: err),
      );

      _favoritesSub = streamFavoritesUseCase(NoParams()).listen(
        (either) => either.fold(
          (failure) =>
              AppLogger.error('Realtime favorites failure: ${failure.message}'),
          (favData) {
            if (!_favoritesController.isClosed) {
              _favoritesController.add(Map<String, dynamic>.from(favData));
            }
          },
        ),
        onError: (err) =>
            AppLogger.error('Favorites stream error: $err', error: err),
      );

      // --------------------
      // Starting Current User Profile updates stream
      // --------------------
      AppLogger.info('RealtimeService: Starting profile updates stream');
      _profileUpdatesSub = streamProfileUpdatesUseCase(userId).listen(
        (either) => either.fold(
          (failure) => AppLogger.error(
            'Realtime profile updates failure: ${failure.message}',
          ),
          (profileData) {
            if (!_profileUpdatesController.isClosed) {
              // Including the user_id in the broadcasted data for context.
              final dataWithId = {
                'user_id': userId,
                ...Map<String, dynamic>.from(profileData),
              };
              _profileUpdatesController.add(dataWithId);
            }
          },
        ),
        onError: (err) =>
            AppLogger.error('Profile updates stream error: $err', error: err),
      );

      // --------------------
      // Starting Notifications (batch) & unread count streams
      // --------------------
      AppLogger.info('RealtimeService: Starting notification streams');

      _notificationsSub = streamNotificationsUseCase(NoParams()).listen(
        (either) => either.fold(
          (failure) {
            AppLogger.error(
              'Realtime notifications failure: ${failure.message}',
            );
            if (!_notificationsController.isClosed) {
              _notificationsController.addError(failure);
            }
          },
          (notifications) {
            if (!_notificationsController.isClosed) {
              final list = List<NotificationEntity>.from(notifications);
              _notificationsController.add(list);
            }
          },
        ),
        onError: (err) {
          AppLogger.error('Notifications stream error: $err', error: err);
          if (!_notificationsController.isClosed) {
            _notificationsController.addError(err);
          }
        },
      );

      _unreadCountSub = streamUnreadCountUseCase(NoParams()).listen(
        (either) => either.fold(
          (failure) {
            AppLogger.error(
              'Realtime unread count failure: ${failure.message}',
            );
            if (!_unreadCountController.isClosed) {
              _unreadCountController.addError(failure);
            }
          },
          (count) {
            if (!_unreadCountController.isClosed) {
              _unreadCountController.add(count);
            }
          },
        ),
        onError: (err) {
          AppLogger.error('Unread count stream error: $err', error: err);
          if (!_unreadCountController.isClosed) {
            _unreadCountController.addError(err);
          }
        },
      );

      // --------------------
      // Starting Global Comments and New Users streams
      // --------------------
      AppLogger.info(
        'RealtimeService: Starting comments and new users streams',
      );

      _commentsSub = streamCommentsUseCase(NoParams()).listen(
        (either) => either.fold(
          (failure) =>
              AppLogger.error('Realtime comments failure: ${failure.message}'),
          (commentData) {
            if (!_commentsController.isClosed) {
              _commentsController.add(Map<String, dynamic>.from(commentData));
            }
          },
        ),
        onError: (err) =>
            AppLogger.error('Comments stream error: $err', error: err),
      );

      // The new users stream requires the current user ID to track follow status.
      _newUsersSub = streamNewUsersUseCase(userId).listen(
        (either) => either.fold(
          (failure) =>
              AppLogger.error('Realtime new user failure: ${failure.message}'),
          (user) {
            if (!_newUserController.isClosed) {
              _newUserController.add(user);
              AppLogger.info('RealtimeService: New user emitted: ${user.id}');
            }
          },
        ),
        onError: (err) =>
            AppLogger.error('New users stream error: $err', error: err),
      );

      _isStarted = true;
      AppLogger.info('RealtimeService started successfully for user $userId');
      AppLogger.info(
        'RealtimeService streams health: ${areStreamsHealthy ? "HEALTHY" : "NO LISTENERS"}',
      );
    } catch (e, st) {
      AppLogger.error(
        'RealtimeService failed to start: $e',
        error: e,
        stackTrace: st,
      );
      await _cancelAll();
      rethrow;
    }
  }

  /// Stops all backing subscriptions but keeps the broadcast controllers open
  /// to allow the service to be restarted later.
  Future<void> stop() async {
    if (!_isStarted) {
      AppLogger.info('RealtimeService.stop called but not started.');
      return;
    }

    AppLogger.info('RealtimeService stopping for user $_currentUserId');
    await _cancelAll();
    await _cancelAdditionalProfileSubs();
    _isStarted = false;
    _currentUserId = null;
    AppLogger.info('RealtimeService stopped');
  }

  /// Manages the cancellation of all main stream subscriptions.
  Future<void> _cancelAll() async {
    try {
      await _newPostsSub?.cancel();
      await _postUpdatesSub?.cancel();
      await _postDeletionsSub?.cancel();
      await _likesSub?.cancel();
      await _favoritesSub?.cancel();
      await _profileUpdatesSub?.cancel();
      await _notificationsSub?.cancel();
      await _unreadCountSub?.cancel();
      await _commentsSub?.cancel();
      await _newUsersSub?.cancel();
    } catch (e) {
      AppLogger.warning('Error cancelling subscriptions: $e');
    } finally {
      _newPostsSub = null;
      _postUpdatesSub = null;
      _postDeletionsSub = null;
      _likesSub = null;
      _favoritesSub = null;
      _profileUpdatesSub = null;
      _notificationsSub = null;
      _unreadCountSub = null;
      _commentsSub = null;
      _newUsersSub = null;
    }
  }

  /// Fully disposes of the service by stopping all subscriptions and closing
  /// all broadcast controllers. This should be called only when the service is
  /// no longer needed (e.g., application shutdown).
  Future<void> dispose() async {
    AppLogger.info('RealtimeService disposing');
    await _cancelAll();
    await _cancelAdditionalProfileSubs();
    try {
      await _newPostController.close();
      await _postUpdatesController.close();
      await _postDeletedController.close();
      await _likesController.close();
      await _favoritesController.close();
      await _profileUpdatesController.close();
      await _notificationsController.close();
      await _unreadCountController.close();
      await _commentsController.close();
      await _newUserController.close();
      AppLogger.info('RealtimeService disposed successfully');
    } catch (e) {
      AppLogger.warning('Failed to close controllers: $e');
    }
  }

  // --- External Profile Subscriptions ---

  /// Subscribes to profile updates for a user other than the currently logged-in one.
  /// This is useful for screens showing another user's profile detail.
  Future<void> subscribeToProfile(String userId) async {
    if (userId == _currentUserId) {
      AppLogger.info('Already subscribed to current user profile: $userId');
      return;
    }

    if (_additionalProfileSubs.containsKey(userId)) {
      AppLogger.info('Already subscribed to profile: $userId');
      return;
    }

    AppLogger.info('Subscribing to additional profile updates for: $userId');
    try {
      final sub = streamProfileUpdatesUseCase(userId).listen(
        (either) => either.fold(
          (failure) => AppLogger.error(
            'Realtime profile update failure for $userId: ${failure.message}',
          ),
          (profileData) {
            if (!_profileUpdatesController.isClosed) {
              // Including the user_id in the broadcasted data for consumer context.
              final dataWithId = {
                'user_id': userId,
                ...Map<String, dynamic>.from(profileData),
              };
              _profileUpdatesController.add(dataWithId);
              AppLogger.info('Profile update emitted for user: $userId');
            }
          },
        ),
        onError: (err) => AppLogger.error(
          'Profile updates stream error for $userId: $err',
          error: err,
        ),
      );
      _additionalProfileSubs[userId] = sub;
    } catch (e) {
      AppLogger.error('Failed to subscribe to profile $userId: $e');
    }
  }

  /// Unsubscribes from profile updates for a specific user.
  Future<void> unsubscribeFromProfile(String userId) async {
    if (userId == _currentUserId ||
        !_additionalProfileSubs.containsKey(userId)) {
      return;
    }

    AppLogger.info('Unsubscribing from profile updates for: $userId');
    await _additionalProfileSubs[userId]?.cancel();
    _additionalProfileSubs.remove(userId);
  }

  /// Cancels all stored profile subscriptions for non-current users.
  Future<void> _cancelAdditionalProfileSubs() async {
    for (final sub in _additionalProfileSubs.values) {
      await sub?.cancel();
    }
    _additionalProfileSubs.clear();
  }
}
