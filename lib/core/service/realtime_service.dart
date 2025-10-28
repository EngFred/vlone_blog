import 'dart:async';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
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

class RealtimeService {
  // Posts
  final StreamNewPostsUseCase streamNewPostsUseCase;
  final StreamPostUpdatesUseCase streamPostUpdatesUseCase;
  final StreamPostDeletionsUseCase streamPostDeletionsUseCase;

  // Likes & Favorites
  final StreamLikesUseCase streamLikesUseCase;
  final StreamFavoritesUseCase streamFavoritesUseCase;

  // Profile updates
  final StreamProfileUpdatesUseCase streamProfileUpdatesUseCase;

  // Notifications
  final GetNotificationsStreamUseCase streamNotificationsUseCase;
  final GetUnreadCountStreamUseCase streamUnreadCountUseCase;

  // Comments (global events)
  final StreamCommentsUseCase streamCommentsUseCase;

  // Broadcast controllers
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

  // Notifications
  final StreamController<List<NotificationEntity>> _notificationsController =
      StreamController<List<NotificationEntity>>.broadcast();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  // Comments (global)
  final StreamController<Map<String, dynamic>> _commentsController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Backing subscriptions (one set)
  StreamSubscription? _newPostsSub;
  StreamSubscription? _postUpdatesSub;
  StreamSubscription? _postDeletionsSub;
  StreamSubscription? _likesSub;
  StreamSubscription? _favoritesSub;
  StreamSubscription? _profileUpdatesSub;
  StreamSubscription? _notificationsSub;
  StreamSubscription? _unreadCountSub;
  StreamSubscription? _commentsSub;

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
  });

  // Public broadcast streams
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

  bool get isStarted => _isStarted;
  String? get currentUserId => _currentUserId;

  /// Check if streams are healthy (have active listeners)
  bool get areStreamsHealthy {
    return _newPostController.hasListener ||
        _postUpdatesController.hasListener ||
        _postDeletedController.hasListener ||
        _likesController.hasListener ||
        _favoritesController.hasListener;
  }

  /// Start the backend subscriptions for the provided userId.
  /// Idempotent: calling start(userId) multiple times is safe.
  Future<void> start(String userId) async {
    if (_isStarted && _currentUserId == userId) {
      AppLogger.info('RealtimeService already started for user $userId');
      return;
    }

    AppLogger.info('RealtimeService starting for user $userId');

    // If started for a different user, stop first.
    if (_isStarted && _currentUserId != userId) {
      await stop();
    }

    _currentUserId = userId;

    try {
      // --------------------
      // Posts streams
      // --------------------
      AppLogger.info('RealtimeService: Starting new posts stream');
      _newPostsSub = streamNewPostsUseCase(NoParams()).listen(
        (either) {
          either.fold(
            (failure) => AppLogger.error(
              'Realtime new post failure: ${failure.message}',
            ),
            (post) {
              try {
                if (!_newPostController.isClosed) {
                  _newPostController.add(post);
                  AppLogger.info(
                    'RealtimeService: New post emitted: ${post.id}',
                  );
                }
              } catch (e) {
                AppLogger.error(
                  'Failed to add new post to controller: $e',
                  error: e,
                );
              }
            },
          );
        },
        onError: (err) =>
            AppLogger.error('New posts stream error: $err', error: err),
      );

      AppLogger.info('RealtimeService: Starting post updates stream');
      _postUpdatesSub = streamPostUpdatesUseCase(NoParams()).listen(
        (either) {
          either.fold(
            (failure) => AppLogger.error(
              'Realtime post update failure: ${failure.message}',
            ),
            (updateData) {
              try {
                if (!_postUpdatesController.isClosed) {
                  _postUpdatesController.add(
                    Map<String, dynamic>.from(updateData),
                  );
                  AppLogger.info(
                    'RealtimeService: Post update emitted for: ${updateData['id']}',
                  );
                }
              } catch (e) {
                AppLogger.error('Failed to forward post update: $e', error: e);
              }
            },
          );
        },
        onError: (err) =>
            AppLogger.error('Post updates stream error: $err', error: err),
      );

      AppLogger.info('RealtimeService: Starting post deletions stream');
      _postDeletionsSub = streamPostDeletionsUseCase(NoParams()).listen(
        (either) {
          either.fold(
            (failure) => AppLogger.error(
              'Realtime post deletion failure: ${failure.message}',
            ),
            (postId) {
              try {
                if (!_postDeletedController.isClosed) {
                  _postDeletedController.add(postId);
                  AppLogger.info(
                    'RealtimeService: Post deletion emitted: $postId',
                  );
                }
              } catch (e) {
                AppLogger.error(
                  'Failed to forward post deletion: $e',
                  error: e,
                );
              }
            },
          );
        },
        onError: (err) =>
            AppLogger.error('Post deletions stream error: $err', error: err),
      );

      // --------------------
      // Likes & Favorites
      // --------------------
      AppLogger.info('RealtimeService: Starting likes stream');
      _likesSub = streamLikesUseCase(NoParams()).listen(
        (either) {
          either.fold(
            (failure) =>
                AppLogger.error('Realtime likes failure: ${failure.message}'),
            (likeData) {
              try {
                if (!_likesController.isClosed) {
                  _likesController.add(Map<String, dynamic>.from(likeData));
                }
              } catch (e) {
                AppLogger.error('Failed to forward like data: $e', error: e);
              }
            },
          );
        },
        onError: (err) =>
            AppLogger.error('Likes stream error: $err', error: err),
      );

      AppLogger.info('RealtimeService: Starting favorites stream');
      _favoritesSub = streamFavoritesUseCase(NoParams()).listen(
        (either) {
          either.fold(
            (failure) => AppLogger.error(
              'Realtime favorites failure: ${failure.message}',
            ),
            (favData) {
              try {
                if (!_favoritesController.isClosed) {
                  _favoritesController.add(Map<String, dynamic>.from(favData));
                }
              } catch (e) {
                AppLogger.error(
                  'Failed to forward favorite data: $e',
                  error: e,
                );
              }
            },
          );
        },
        onError: (err) =>
            AppLogger.error('Favorites stream error: $err', error: err),
      );

      // --------------------
      // Profile updates
      // --------------------
      AppLogger.info('RealtimeService: Starting profile updates stream');
      _profileUpdatesSub = streamProfileUpdatesUseCase(userId).listen(
        (either) {
          either.fold(
            (failure) => AppLogger.error(
              'Realtime profile updates failure: ${failure.message}',
            ),
            (profileData) {
              try {
                if (!_profileUpdatesController.isClosed) {
                  _profileUpdatesController.add(
                    Map<String, dynamic>.from(profileData),
                  );
                }
              } catch (e) {
                AppLogger.error(
                  'Failed to forward profile update: $e',
                  error: e,
                );
              }
            },
          );
        },
        onError: (err) =>
            AppLogger.error('Profile updates stream error: $err', error: err),
      );

      // --------------------
      // Notifications (batch) & unread count
      // --------------------
      AppLogger.info('RealtimeService: Starting notifications stream');
      _notificationsSub = streamNotificationsUseCase(NoParams()).listen(
        (either) {
          either.fold(
            (failure) {
              AppLogger.error(
                'Realtime notifications failure: ${failure.message}',
              );
              try {
                if (!_notificationsController.isClosed) {
                  _notificationsController.addError(failure);
                }
              } catch (_) {}
            },
            (notifications) {
              try {
                if (!_notificationsController.isClosed) {
                  final list = List<NotificationEntity>.from(notifications);
                  _notificationsController.add(list);
                }
              } catch (e) {
                AppLogger.error(
                  'Failed to forward notifications batch: $e',
                  error: e,
                );
              }
            },
          );
        },
        onError: (err) {
          AppLogger.error('Notifications stream error: $err', error: err);
          if (!_notificationsController.isClosed) {
            _notificationsController.addError(err);
          }
        },
      );

      AppLogger.info('RealtimeService: Starting unread count stream');
      _unreadCountSub = streamUnreadCountUseCase(NoParams()).listen(
        (either) {
          either.fold(
            (failure) {
              AppLogger.error(
                'Realtime unread count failure: ${failure.message}',
              );
              try {
                if (!_unreadCountController.isClosed) {
                  _unreadCountController.addError(failure);
                }
              } catch (_) {}
            },
            (count) {
              try {
                if (!_unreadCountController.isClosed) {
                  _unreadCountController.add(count);
                }
              } catch (e) {
                AppLogger.error('Failed to forward unread count: $e', error: e);
              }
            },
          );
        },
        onError: (err) {
          AppLogger.error('Unread count stream error: $err', error: err);
          if (!_unreadCountController.isClosed) {
            _unreadCountController.addError(err);
          }
        },
      );

      // --------------------
      // Comments (global events)
      // --------------------
      AppLogger.info('RealtimeService: Starting comments stream');
      _commentsSub = streamCommentsUseCase(NoParams()).listen(
        (either) {
          either.fold(
            (failure) => AppLogger.error(
              'Realtime comments failure: ${failure.message}',
            ),
            (commentData) {
              try {
                if (!_commentsController.isClosed) {
                  _commentsController.add(
                    Map<String, dynamic>.from(commentData),
                  );
                }
              } catch (e) {
                AppLogger.error('Failed to forward comment data: $e', error: e);
              }
            },
          );
        },
        onError: (err) =>
            AppLogger.error('Comments stream error: $err', error: err),
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

  /// Stop backing subscriptions but keep controllers open for future starts.
  Future<void> stop() async {
    if (!_isStarted) {
      AppLogger.info('RealtimeService.stop called but not started.');
      return;
    }

    AppLogger.info('RealtimeService stopping for user $_currentUserId');
    await _cancelAll();
    _isStarted = false;
    _currentUserId = null;
    AppLogger.info('RealtimeService stopped');
  }

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
    }
  }

  /// Fully dispose the service (close controllers).
  Future<void> dispose() async {
    AppLogger.info('RealtimeService disposing');
    await _cancelAll();
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
      AppLogger.info('RealtimeService disposed successfully');
    } catch (e) {
      AppLogger.warning('Failed to close controllers: $e');
    }
  }
}
