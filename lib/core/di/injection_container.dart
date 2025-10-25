import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'package:vlone_blog_app/features/comments/domain/usecases/get_comments_usecase.dart';
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
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_notifications_stream_usecase.dart';
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
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';

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
import 'package:vlone_blog_app/features/users/domain/usecases/get_all_users_usecase.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';

final sl = GetIt.instance;

/// ✅ OPTIMIZED: Accept pre-initialized SupabaseClient to avoid duplicate initialization
/// This function is now called from main() AFTER Supabase.initialize()
Future<void> init({SupabaseClient? supabaseClient}) async {
  await initAuth(supabaseClient: supabaseClient);
  await initPosts();
  await initLikes();
  await initFavorites();
  await initComments();
  await initProfile();
  await initFollowers();
  await initUsers();
}

/// Init only auth-related dependencies first for faster startup
Future<void> initAuth({SupabaseClient? supabaseClient}) async {
  // External - Use provided client or get from instance
  // ✅ PERFORMANCE: This prevents the "already initialized" warning
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
  // Posts Feature
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
  // Real-time post streams used in PostsBloc
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

  sl.registerFactory<PostsBloc>(
    () => PostsBloc(
      createPostUseCase: sl<CreatePostUseCase>(),
      getFeedUseCase: sl<GetFeedUseCase>(),
      getReelsUseCase: sl<GetReelsUseCase>(),
      getUserPostsUseCase: sl<GetUserPostsUseCase>(),
      sharePostUseCase: sl<SharePostUseCase>(),
      getPostUseCase: sl<GetPostUseCase>(),
      deletePostUseCase: sl<DeletePostUseCase>(),
      streamNewPostsUseCase: sl<StreamNewPostsUseCase>(),
      streamPostUpdatesUseCase: sl<StreamPostUpdatesUseCase>(),
      streamPostDeletionsUseCase: sl<StreamPostDeletionsUseCase>(),
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
      streamLikesUseCase: sl<StreamLikesUseCase>(),
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
      streamFavoritesUseCase: sl<StreamFavoritesUseCase>(),
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
  sl.registerLazySingleton<GetCommentsUseCase>(
    () => GetCommentsUseCase(sl<CommentsRepository>()),
  );
  sl.registerLazySingleton<StreamCommentsUseCase>(
    () => StreamCommentsUseCase(sl<CommentsRepository>()),
  );
  sl.registerFactory<CommentsBloc>(
    () => CommentsBloc(
      addCommentUseCase: sl<AddCommentUseCase>(),
      getCommentsUseCase: sl<GetCommentsUseCase>(),
      streamCommentsUseCase: sl<StreamCommentsUseCase>(),
      repository: sl<CommentsRepository>(),
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
      streamProfileUpdatesUseCase: sl<StreamProfileUpdatesUseCase>(),
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
  sl.registerLazySingleton(() => GetAllUsersUseCase(sl<UsersRepository>()));
  sl.registerFactory(() => UsersBloc(getAllUsersUseCase: sl()));
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
  sl.registerFactory<NotificationsBloc>(
    () => NotificationsBloc(
      getNotificationsStreamUseCase: sl<GetNotificationsStreamUseCase>(),
      markAsReadUseCase: sl<MarkAsReadUseCase>(),
      markAllAsReadUseCase: sl<MarkAllAsReadUseCase>(),
      getUnreadCountStreamUseCase: sl<GetUnreadCountStreamUseCase>(),
    ),
  );
}
