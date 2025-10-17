import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_feed_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/like_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/share_post_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_user_posts_usecase.dart';

part 'posts_event.dart';
part 'posts_state.dart';

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final CreatePostUseCase createPostUseCase;
  final GetFeedUseCase getFeedUseCase;
  final LikePostUseCase likePostUseCase;
  final SharePostUseCase sharePostUseCase;
  final GetUserPostsUseCase getUserPostsUseCase;
  final PostsRepository repository;

  PostsBloc({
    required this.createPostUseCase,
    required this.getFeedUseCase,
    required this.likePostUseCase,
    required this.sharePostUseCase,
    required this.getUserPostsUseCase,
    required this.repository,
  }) : super(PostsInitial()) {
    on<CreatePostEvent>((event, emit) async {
      AppLogger.info('CreatePostEvent triggered for user: ${event.userId}');
      emit(PostsLoading());
      final result = await createPostUseCase(
        CreatePostParams(
          userId: event.userId,
          content: event.content,
          mediaFile: event.mediaFile,
          mediaType: event.mediaType,
        ),
      );
      result.fold(
        (failure) {
          AppLogger.error('Create post failed: ${failure.message}');
          emit(PostsError(failure.message));
        },
        (post) {
          AppLogger.info('Post created successfully: ${post.id}');
          emit(PostCreated(post));
        },
      );
    });

    on<GetFeedEvent>((event, emit) async {
      AppLogger.info('GetFeedEvent triggered for page: ${event.page}');
      emit(PostsLoading());
      final result = await getFeedUseCase(
        GetFeedParams(page: event.page, limit: event.limit),
      );
      result.fold(
        (failure) {
          AppLogger.error('Get feed failed: ${failure.message}');
          emit(PostsError(failure.message));
        },
        (posts) {
          AppLogger.info('Feed loaded with ${posts.length} posts');
          emit(FeedLoaded(posts));
        },
      );
    });

    on<GetUserPostsEvent>((event, emit) async {
      AppLogger.info(
        'GetUserPostsEvent triggered for user: ${event.userId}, page: ${event.page}',
      );
      emit(PostsLoading());
      final result = await getUserPostsUseCase(
        GetUserPostsParams(
          userId: event.userId,
          page: event.page,
          limit: event.limit,
        ),
      );
      result.fold(
        (failure) {
          AppLogger.error('Get user posts failed: ${failure.message}');
          emit(PostsError(failure.message));
        },
        (posts) {
          AppLogger.info('User posts loaded with ${posts.length} posts');
          emit(UserPostsLoaded(posts));
        },
      );
    });

    on<LikePostEvent>((event, emit) async {
      AppLogger.info(
        'LikePostEvent triggered for post: ${event.postId}, like: ${!event.isLiked}',
      );
      final result = await likePostUseCase(
        LikePostParams(
          postId: event.postId,
          userId: event.userId,
          isLiked: event.isLiked,
        ),
      );
      result.fold(
        (failure) {
          AppLogger.error('Like post failed: ${failure.message}');
          emit(PostsError(failure.message));
        },
        (_) {
          AppLogger.info('Post liked/unliked successfully');
          emit(PostLiked(event.postId, !event.isLiked));
        },
      );
    });

    on<SharePostEvent>((event, emit) async {
      AppLogger.info('SharePostEvent triggered for post: ${event.postId}');
      final result = await sharePostUseCase(
        SharePostParams(postId: event.postId),
      );
      result.fold(
        (failure) {
          AppLogger.error('Share post failed: ${failure.message}');
          emit(PostsError(failure.message));
        },
        (_) {
          AppLogger.info('Post shared successfully');
          emit(PostShared(event.postId));
        },
      );
    });

    on<SubscribeToFeedEvent>((event, emit) {
      AppLogger.info('SubscribeToFeedEvent triggered');
      repository.getFeedStream().listen((newPosts) {
        add(NewPostsEvent(newPosts));
      });
    });

    on<NewPostsEvent>((event, emit) {
      AppLogger.info(
        'NewPostsEvent received with ${event.newPosts.length} new posts',
      );
      if (state is FeedLoaded) {
        final currentPosts = (state as FeedLoaded).posts;
        final updatedPosts = [...event.newPosts, ...currentPosts];
        emit(FeedLoaded(updatedPosts));
      }
    });
  }
}
