import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:vlone_blog_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vlone_blog_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/signup_usecase.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/posts/data/datasources/posts_remote_datasource.dart';
import 'package:vlone_blog_app/features/posts/data/repositories/posts_repository_impl.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/favorite_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_favorites_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_feed_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_interactions_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_reels_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/like_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/share_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/stream_posts_usecase.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vlone_blog_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:vlone_blog_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_user_posts_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/stream_profile_updates_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/comments/data/datasources/comments_remote_datasource.dart';
import 'package:vlone_blog_app/features/comments/data/repositories/comments_repository_impl.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/add_comment_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/get_comments_usecase.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/followers/data/datasources/followers_remote_datasource.dart';
import 'package:vlone_blog_app/features/followers/data/repositories/followers_repository_impl.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/follow_user_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_followers_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_following_usecase.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/users/data/datasources/users_remote_datasource.dart';
import 'package:vlone_blog_app/features/users/data/repository/users_repository_impl.dart';
import 'package:vlone_blog_app/features/users/domain/repository/users_repository.dart';
import 'package:vlone_blog_app/features/users/domain/usecases/get_all_users_usecase.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  sl.registerLazySingleton<SupabaseClient>(() {
    Supabase.initialize(
      url: Constants.supabaseUrl,
      anonKey: Constants.supabaseAnonKey,
    );
    return Supabase.instance.client;
  });

  // Auth Feature
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

  // Profile Feature
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
  sl.registerLazySingleton(
    () => StreamProfileUpdatesUseCase(sl<ProfileRepository>()),
  );
  sl.registerFactory<ProfileBloc>(
    () => ProfileBloc(
      getProfileUseCase: sl<GetProfileUseCase>(),
      updateProfileUseCase: sl<UpdateProfileUseCase>(),
      streamProfileUpdatesUseCase: sl<StreamProfileUpdatesUseCase>(),
    ),
  );

  // Posts Feature
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
  sl.registerLazySingleton<LikePostUseCase>(
    () => LikePostUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<SharePostUseCase>(
    () => SharePostUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<GetPostInteractionsUseCase>(
    () => GetPostInteractionsUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton<GetReelsUseCase>(
    () => GetReelsUseCase(sl<PostsRepository>()),
  );
  sl.registerLazySingleton(() => FavoritePostUseCase(sl<PostsRepository>()));

  //get favorites
  sl.registerLazySingleton(() => GetFavoritesUseCase(sl<PostsRepository>()));

  // Real-time use cases
  sl.registerLazySingleton(() => StreamNewPostsUseCase(sl()));
  sl.registerLazySingleton(() => StreamPostUpdatesUseCase(sl()));
  sl.registerLazySingleton(() => StreamLikesUseCase(sl()));
  sl.registerLazySingleton(() => StreamCommentsUseCase(sl()));
  sl.registerLazySingleton(() => StreamFavoritesUseCase(sl()));

  sl.registerFactory<PostsBloc>(
    () => PostsBloc(
      createPostUseCase: sl<CreatePostUseCase>(),
      getFeedUseCase: sl<GetFeedUseCase>(),
      likePostUseCase: sl<LikePostUseCase>(),
      favoritePostUseCase: sl<FavoritePostUseCase>(),
      getReelsUseCase: sl<GetReelsUseCase>(),
      sharePostUseCase: sl<SharePostUseCase>(),
      getPostUseCase: sl<GetPostUseCase>(),
      getUserPostsUseCase: sl<GetUserPostsUseCase>(),
      streamNewPostsUseCase: sl(),
      streamPostUpdatesUseCase: sl(),
      streamLikesUseCase: sl(),
      streamCommentsUseCase: sl(),
      streamFavoritesUseCase: sl(),
    ),
  );

  // Comments Feature
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
  sl.registerFactory<CommentsBloc>(
    () => CommentsBloc(
      addCommentUseCase: sl<AddCommentUseCase>(),
      getCommentsUseCase: sl<GetCommentsUseCase>(),
      repository: sl<CommentsRepository>(),
    ),
  );

  // Followers Feature
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
  sl.registerFactory<FollowersBloc>(
    () => FollowersBloc(
      followUserUseCase: sl<FollowUserUseCase>(),
      getFollowersUseCase: sl<GetFollowersUseCase>(),
      getFollowingUseCase: sl<GetFollowingUseCase>(),
    ),
  );

  //users
  sl.registerLazySingleton<UsersRemoteDataSource>(
    () => UsersRemoteDataSource(sl()),
  );
  sl.registerLazySingleton<UsersRepository>(() => UsersRepositoryImpl(sl()));
  sl.registerLazySingleton(() => GetAllUsersUseCase(sl()));
  sl.registerFactory(() => UsersBloc(getAllUsersUseCase: sl()));
}
