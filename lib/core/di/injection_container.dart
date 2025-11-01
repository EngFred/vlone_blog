import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/service/media_download_service.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';

// Auth
import 'package:vlone_blog_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:vlone_blog_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vlone_blog_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/signup_usecase.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

// Comments
import 'package:vlone_blog_app/features/comments/data/datasources/comments_remote_datasource.dart';
import 'package:vlone_blog_app/features/comments/data/repositories/comments_repository_impl.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/add_comment_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/get_initial_comments_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/load_more_comments_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/stream_comments_usecase.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';

// Favorites
import 'package:vlone_blog_app/features/favorites/data/datasources/favorites_data_source.dart';
import 'package:vlone_blog_app/features/favorites/data/repository/favorites_repository_impl.dart';
import 'package:vlone_blog_app/features/favorites/domain/repository/favorites_repository.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/favorite_post_usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/stream_favorites_usecase.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';

// Followers
import 'package:vlone_blog_app/features/followers/data/datasources/followers_remote_datasource.dart';
import 'package:vlone_blog_app/features/followers/data/repositories/followers_repository_impl.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/follow_user_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_followers_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_following_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_follow_status_usecase.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';

// Likes
import 'package:vlone_blog_app/features/likes/data/datasources/likes_remote_data_source.dart';
import 'package:vlone_blog_app/features/likes/data/repository/likes_repository_impl.dart';
import 'package:vlone_blog_app/features/likes/domain/repository/likes_repository.dart';
import 'package:vlone_blog_app/features/likes/domain/usecases/like_post_usecase.dart';
import 'package:vlone_blog_app/features/likes/domain/usecases/stream_likes_usecase.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:vlone_blog_app/features/notifications/data/repository/notification_repository_impl.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/delete_notifications_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_notifications_stream_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_paginated_notifications_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_unread_count_stream_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/mark_all_as_read_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/mark_notification_as_read_usecase.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';

// Posts
import 'package:vlone_blog_app/features/posts/data/datasources/posts_remote_datasource.dart';
import 'package:vlone_blog_app/features/posts/data/repositories/posts_repository_impl.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/delete_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_feed_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_reels_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_user_posts_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/share_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/stream_post_deletions_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/stream_posts_usecase.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/feed/feed_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';

// Profile
import 'package:vlone_blog_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vlone_blog_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:vlone_blog_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/stream_profile_updates_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';

// Users
import 'package:vlone_blog_app/features/users/data/datasources/users_remote_datasource.dart';
import 'package:vlone_blog_app/features/users/data/repository/users_repository_impl.dart';
import 'package:vlone_blog_app/features/users/domain/repository/users_repository.dart';
import 'package:vlone_blog_app/features/users/domain/usecases/get_paginated_users_usecase.dart';
import 'package:vlone_blog_app/features/users/domain/usecases/stream_new_users_usecase.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';

// Settings
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vlone_blog_app/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:vlone_blog_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:vlone_blog_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:vlone_blog_app/features/settings/domain/usecases/get_theme_mode.dart';
import 'package:vlone_blog_app/features/settings/domain/usecases/save_theme_mode.dart';
import 'package:vlone_blog_app/features/settings/presentation/bloc/settings_bloc.dart';

final sl = GetIt.instance;

// -------------------
// Core Services Registration
// -------------------
void initCoreServices() {
  // Register MediaDownloadService as a LazySingleton
  // GetIt will manage the single instance lifecycle for you.
  sl.registerLazySingleton<MediaDownloadService>(() => MediaDownloadService());
}

/// Init only auth-related dependencies first for faster startup
Future<void> initAuth({SupabaseClient? supabaseClient}) async {
  // External - Use provided client or get from instance
  // PERFORMANCE: This prevents the "already initialized" warning
  // and saves ~50-100ms by not re-initializing Supabase
  sl.registerLazySingleton<SupabaseClient>(() {
    if (supabaseClient != null) {
      return supabaseClient;
    }
    // Fallback if not provided (shouldn't happen in normal flow)
    return Supabase.instance.client;
  });
  // -------------------
  // Auth Feature
  // -------------------
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>()),
  );
  sl.registerLazySingleton<SignupUseCase>(
    () => SignupUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton<GetCurrentUserUseCase>(
    () => GetCurrentUserUseCase(sl<AuthRepository>()),
  );
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      signupUseCase: sl<SignupUseCase>(),
      loginUseCase: sl<LoginUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
      authRepository: sl<AuthRepository>(),
    ),
  );
}

Future<void> initPosts() async {
  // -------------------
  // Posts Feature Use Cases (No change here)
  // -------------------
  sl.registerLazySingleton<PostsRemoteDataSource>(
    () => PostsRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<PostsRepository>(
    () => PostsRepositoryImpl(sl<PostsRemoteDataSource>()),
  );
  sl.registerLazySingleton<CreatePostUseCase>(
    () => CreatePostUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<GetFeedUseCase>(
    () => GetFeedUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<GetUserPostsUseCase>(
    () => GetUserPostsUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<GetPostUseCase>(
    () => GetPostUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<SharePostUseCase>(
    () => SharePostUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<GetReelsUseCase>(
    () => GetReelsUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<DeletePostUseCase>(
    () => DeletePostUseCase(sl<PostsRepository>()),
  );
  // -------------------
  // Real-time post streams used in new BLoCs (No change here)
  // -------------------
  sl.registerLazySingleton<StreamNewPostsUseCase>(
    () => StreamNewPostsUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<StreamPostUpdatesUseCase>(
    () => StreamPostUpdatesUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<StreamPostDeletionsUseCase>(
    () => StreamPostDeletionsUseCase(sl<PostsRepository>()),
  );
  // 1. FeedsBloc
  sl.registerFactory<FeedBloc>(
    () => FeedBloc(
      getFeedUseCase: sl<GetFeedUseCase>(),
      realtimeService: sl<RealtimeService>(),
    ),
  );
  // 2. ReelsBloc
  sl.registerFactory<ReelsBloc>(
    () => ReelsBloc(
      getReelsUseCase: sl<GetReelsUseCase>(),
      realtimeService: sl<RealtimeService>(),
    ),
  );
  // 3. PostActionsBloc
  // Handles single post creation, sharing, deletion, and is used for optimistic UI updates
  sl.registerFactory<PostActionsBloc>(
    () => PostActionsBloc(
      createPostUseCase: sl<CreatePostUseCase>(),
      sharePostUseCase: sl<SharePostUseCase>(),
      deletePostUseCase: sl<DeletePostUseCase>(),
      getPostUseCase: sl<GetPostUseCase>(),
    ),
  );
  // 4. UserPostsBloc
  // Handles a specific user's paginated posts
  sl.registerFactory<UserPostsBloc>(
    () => UserPostsBloc(
      getUserPostsUseCase: sl<GetUserPostsUseCase>(),
      realtimeService: sl<RealtimeService>(),
    ),
  );
}

Future<void> initLikes() async {
  // -------------------
  // Likes Feature
  // -------------------
  sl.registerLazySingleton<LikesRemoteDataSource>(
    () => LikesRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<LikesRepository>(
    () => LikesRepositoryImpl(sl<LikesRemoteDataSource>()),
  );
  sl.registerLazySingleton<LikePostUseCase>(
    () => LikePostUseCase(sl<LikesRepository>()),
  );
  sl.registerLazySingleton<StreamLikesUseCase>(
    () => StreamLikesUseCase(sl<LikesRepository>()),
  );
  sl.registerFactory<LikesBloc>(
    () => LikesBloc(
      likePostUseCase: sl<LikePostUseCase>(),
      realtimeService: sl<RealtimeService>(),
    ),
  );
}

Future<void> initFavorites() async {
  // -------------------
  // Favorites Feature
  // -------------------
  sl.registerLazySingleton<FavoritesRemoteDataSource>(
    () => FavoritesRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(sl<FavoritesRemoteDataSource>()),
  );
  sl.registerLazySingleton<FavoritePostUseCase>(
    () => FavoritePostUseCase(sl<FavoritesRepository>()),
  );
  sl.registerLazySingleton<GetFavoritesUseCase>(
    () => GetFavoritesUseCase(sl<FavoritesRepository>()),
  );
  sl.registerLazySingleton<StreamFavoritesUseCase>(
    () => StreamFavoritesUseCase(sl<FavoritesRepository>()),
  );
  sl.registerFactory<FavoritesBloc>(
    () => FavoritesBloc(
      favoritePostUseCase: sl<FavoritePostUseCase>(),
      realtimeService: sl<RealtimeService>(),
    ),
  );
}

Future<void> initComments() async {
  // -------------------
  // Comments Feature
  // -------------------
  sl.registerLazySingleton<CommentsRemoteDataSource>(
    () => CommentsRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<CommentsRepository>(
    () => CommentsRepositoryImpl(sl<CommentsRemoteDataSource>()),
  );
  sl.registerLazySingleton<AddCommentUseCase>(
    () => AddCommentUseCase(sl<CommentsRepository>()),
  );
  sl.registerLazySingleton<GetInitialCommentsUseCase>(
    () => GetInitialCommentsUseCase(sl<CommentsRepository>()),
  );
  sl.registerLazySingleton<StreamCommentsUseCase>(
    () => StreamCommentsUseCase(sl<CommentsRepository>()),
  );
  sl.registerLazySingleton<LoadMoreCommentsUseCase>(
    () => LoadMoreCommentsUseCase(sl<CommentsRepository>()),
  );
  sl.registerFactory<CommentsBloc>(
    () => CommentsBloc(
      getInitialCommentsUseCase: sl<GetInitialCommentsUseCase>(),
      addCommentUseCase: sl<AddCommentUseCase>(),
      streamCommentsUseCase: sl<StreamCommentsUseCase>(),
      repository: sl<CommentsRepository>(),
      realtimeService: sl<RealtimeService>(),
      loadMoreCommentsUseCase: sl<LoadMoreCommentsUseCase>(),
    ),
  );
}

Future<void> initProfile() async {
  // -------------------
  // Profile Feature
  // -------------------
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
  );
  sl.registerLazySingleton<GetProfileUseCase>(
    () => GetProfileUseCase(sl<ProfileRepository>()),
  );
  sl.registerLazySingleton<UpdateProfileUseCase>(
    () => UpdateProfileUseCase(sl<ProfileRepository>()),
  );
  sl.registerLazySingleton<StreamProfileUpdatesUseCase>(
    () => StreamProfileUpdatesUseCase(sl<ProfileRepository>()),
  );
  sl.registerFactory<ProfileBloc>(
    () => ProfileBloc(
      getProfileUseCase: sl<GetProfileUseCase>(),
      updateProfileUseCase: sl<UpdateProfileUseCase>(),
      realtimeService: sl<RealtimeService>(),
    ),
  );
}

Future<void> initFollowers() async {
  // -------------------
  // Followers Feature
  // -------------------
  sl.registerLazySingleton<FollowersRemoteDataSource>(
    () => FollowersRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<FollowersRepository>(
    () => FollowersRepositoryImpl(sl<FollowersRemoteDataSource>()),
  );
  sl.registerLazySingleton<FollowUserUseCase>(
    () => FollowUserUseCase(sl<FollowersRepository>()),
  );
  sl.registerLazySingleton<GetFollowersUseCase>(
    () => GetFollowersUseCase(sl<FollowersRepository>()),
  );
  sl.registerLazySingleton<GetFollowingUseCase>(
    () => GetFollowingUseCase(sl<FollowersRepository>()),
  );
  sl.registerLazySingleton<GetFollowStatusUseCase>(
    () => GetFollowStatusUseCase(sl<FollowersRepository>()),
  );
  sl.registerFactory<FollowersBloc>(
    () => FollowersBloc(
      followUserUseCase: sl<FollowUserUseCase>(),
      getFollowersUseCase: sl<GetFollowersUseCase>(),
      getFollowingUseCase: sl<GetFollowingUseCase>(),
      getFollowStatusUseCase: sl<GetFollowStatusUseCase>(),
    ),
  );
}

Future<void> initUsers() async {
  // -------------------
  // Users Feature
  // -------------------
  sl.registerLazySingleton<UsersRemoteDataSource>(
    () => UsersRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<UsersRepository>(
    () => UsersRepositoryImpl(sl<UsersRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetPaginatedUsersUseCase(sl<UsersRepository>()),
  );
  sl.registerLazySingleton<StreamNewUsersUseCase>(
    () => StreamNewUsersUseCase(sl<UsersRepository>()),
  );
  sl.registerFactory(() => UsersBloc(getPaginatedUsersUseCase: sl()));
}

// -------------------
// Notifications Feature
// -------------------
Future<void> initNotifications() async {
  sl.registerLazySingleton<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(sl<NotificationsRemoteDataSource>()),
  );
  sl.registerLazySingleton<GetNotificationsStreamUseCase>(
    () => GetNotificationsStreamUseCase(sl<NotificationsRepository>()),
  );
  sl.registerLazySingleton<MarkAsReadUseCase>(
    () => MarkAsReadUseCase(sl<NotificationsRepository>()),
  );
  sl.registerLazySingleton<MarkAllAsReadUseCase>(
    () => MarkAllAsReadUseCase(sl<NotificationsRepository>()),
  );
  sl.registerLazySingleton<GetUnreadCountStreamUseCase>(
    () => GetUnreadCountStreamUseCase(sl<NotificationsRepository>()),
  );
  sl.registerLazySingleton<DeleteNotificationsUseCase>(
    () => DeleteNotificationsUseCase(sl<NotificationsRepository>()),
  );
  sl.registerLazySingleton<GetPaginatedNotificationsUseCase>(
    () => GetPaginatedNotificationsUseCase(sl<NotificationsRepository>()),
  );
  sl.registerFactory<NotificationsBloc>(
    () => NotificationsBloc(
      markAsReadUseCase: sl<MarkAsReadUseCase>(),
      markAllAsReadUseCase: sl<MarkAllAsReadUseCase>(),
      deleteNotificationsUseCase: sl<DeleteNotificationsUseCase>(),
      realtimeService: sl<RealtimeService>(),
      getPaginatedNotificationsUseCase: sl<GetPaginatedNotificationsUseCase>(),
    ),
  );
}

// -------------------
// Settings Feature
// -------------------
Future<void> initSettings() async {
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSource(sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<GetThemeMode>(() => GetThemeMode(sl()));
  sl.registerLazySingleton<SaveThemeMode>(() => SaveThemeMode(sl()));
  sl.registerFactory<SettingsBloc>(() => SettingsBloc(sl(), sl()));
}

Future<void> initRealtime() async {
  // Ensure the stream usecases are already registered (or register them here).
  sl.registerLazySingleton<RealtimeService>(
    () => RealtimeService(
      streamNewPostsUseCase: sl<StreamNewPostsUseCase>(),
      streamPostUpdatesUseCase: sl<StreamPostUpdatesUseCase>(),
      streamPostDeletionsUseCase: sl<StreamPostDeletionsUseCase>(),
      streamLikesUseCase: sl<StreamLikesUseCase>(),
      streamFavoritesUseCase: sl<StreamFavoritesUseCase>(),
      streamProfileUpdatesUseCase: sl<StreamProfileUpdatesUseCase>(),
      streamCommentsUseCase: sl<StreamCommentsUseCase>(),
      streamNotificationsUseCase: sl<GetNotificationsStreamUseCase>(),
      streamUnreadCountUseCase: sl<GetUnreadCountStreamUseCase>(),
      streamNewUsersUseCase: sl<StreamNewUsersUseCase>(),
    ),
  );
}
