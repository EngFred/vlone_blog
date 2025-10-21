import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_feed_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_interactions_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_reels_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_user_posts_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/like_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/share_post_usecase.dart';

part 'posts_event.dart';
part 'posts_state.dart';

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final CreatePostUseCase createPostUseCase;
  final GetFeedUseCase getFeedUseCase;
  final GetReelsUseCase getReelsUseCase;
  final GetUserPostsUseCase getUserPostsUseCase;
  final LikePostUseCase likePostUseCase;
  final SharePostUseCase sharePostUseCase;
  final GetPostUseCase getPostUseCase;
  final PostsRepository repository;

  PostsBloc({
    required this.createPostUseCase,
    required this.getFeedUseCase,
    required this.getReelsUseCase,
    required this.getUserPostsUseCase,
    required this.likePostUseCase,
    required this.sharePostUseCase,
    required this.getPostUseCase,
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
      AppLogger.info('GetFeedEvent triggered');
      emit(PostsLoading());
      final result = await getFeedUseCase(NoParams());
      await result.fold(
        (failure) async {
          AppLogger.error('Get feed failed: ${failure.message}');
          emit(PostsError(failure.message));
        },
        (posts) async {
          List<PostEntity> updatedPosts = posts;
          if (event.userId != null) {
            final postIds = posts.map((p) => p.id).toList();
            final interResult = await sl<GetPostInteractionsUseCase>()(
              GetPostInteractionsParams(
                userId: event.userId!,
                postIds: postIds,
              ),
            );
            interResult.fold(
              (failure) {
                AppLogger.error(
                  'Failed to fetch interactions for feed: ${failure.message}',
                );
                // Continue with defaults
              },
              (states) {
                updatedPosts = posts
                    .map(
                      (p) => p.copyWith(
                        isLiked: states.isLiked(p.id),
                        isFavorited: states.isFavorited(p.id),
                      ),
                    )
                    .toList();
              },
            );
          }
          AppLogger.info('Feed loaded with ${updatedPosts.length} posts');
          emit(FeedLoaded(updatedPosts));
        },
      );
    });
    on<GetReelsEvent>((event, emit) async {
      AppLogger.info('GetReelsEvent triggered');
      emit(PostsLoading());
      final result = await getReelsUseCase(NoParams());
      await result.fold(
        (failure) async {
          AppLogger.error('Get reels failed: ${failure.message}');
          emit(PostsError(failure.message));
        },
        (posts) async {
          List<PostEntity> updatedPosts = posts;
          if (event.userId != null) {
            final postIds = posts.map((p) => p.id).toList();
            final interResult = await sl<GetPostInteractionsUseCase>()(
              GetPostInteractionsParams(
                userId: event.userId!,
                postIds: postIds,
              ),
            );
            interResult.fold(
              (failure) {
                AppLogger.error(
                  'Failed to fetch interactions for reels: ${failure.message}',
                );
                // Continue with defaults
              },
              (states) {
                updatedPosts = posts
                    .map(
                      (p) => p.copyWith(
                        isLiked: states.isLiked(p.id),
                        isFavorited: states.isFavorited(p.id),
                      ),
                    )
                    .toList();
              },
            );
          }
          AppLogger.info('Reels loaded with ${updatedPosts.length} posts');
          emit(ReelsLoaded(updatedPosts));
        },
      );
    });
    on<GetUserPostsEvent>((event, emit) async {
      AppLogger.info(
        'GetUserPostsEvent triggered for user: ${event.profileUserId}',
      );
      emit(UserPostsLoading());
      final result = await getUserPostsUseCase(
        GetUserPostsParams(userId: event.profileUserId),
      );
      await result.fold(
        (failure) async {
          AppLogger.error('Get user posts failed: ${failure.message}');
          emit(UserPostsError(failure.message));
        },
        (posts) async {
          List<PostEntity> updatedPosts = posts;
          if (event.viewerUserId != null) {
            final postIds = posts.map((p) => p.id).toList();
            final interResult = await sl<GetPostInteractionsUseCase>()(
              GetPostInteractionsParams(
                userId: event.viewerUserId!,
                postIds: postIds,
              ),
            );
            interResult.fold(
              (failure) {
                AppLogger.error(
                  'Failed to fetch interactions for user posts: ${failure.message}',
                );
                // Continue with defaults
              },
              (states) {
                updatedPosts = posts
                    .map(
                      (p) => p.copyWith(
                        isLiked: states.isLiked(p.id),
                        isFavorited: states.isFavorited(p.id),
                      ),
                    )
                    .toList();
              },
            );
          }
          AppLogger.info('User posts loaded with ${updatedPosts.length} posts');
          emit(UserPostsLoaded(updatedPosts));
        },
      );
    });
    on<GetPostEvent>((event, emit) async {
      AppLogger.info('GetPostEvent for post: ${event.postId}');
      final result = await getPostUseCase(event.postId);
      result.fold(
        (failure) {
          AppLogger.error('Get post failed: ${failure.message}');
          emit(PostsError(failure.message));
        },
        (post) async {
          PostEntity updatedPost = post;
          if (event.viewerUserId != null) {
            final interResult = await sl<GetPostInteractionsUseCase>()(
              GetPostInteractionsParams(
                userId: event.viewerUserId!,
                postIds: [post.id],
              ),
            );
            interResult.fold(
              (failure) => AppLogger.error(
                'Interactions fetch failed: ${failure.message}',
              ),
              (states) {
                updatedPost = post.copyWith(
                  isLiked: states.isLiked(post.id),
                  isFavorited: states.isFavorited(post.id),
                );
              },
            );
          }
          AppLogger.info('Post loaded: ${updatedPost.id}');
          emit(PostLoaded(updatedPost));
        },
      );
    });
    on<LikePostEvent>((event, emit) async {
      AppLogger.info(
        'LikePostEvent triggered for post: ${event.postId}, like: ${event.isLiked}',
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
          emit(PostLiked(event.postId, event.isLiked));
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
  }
}
