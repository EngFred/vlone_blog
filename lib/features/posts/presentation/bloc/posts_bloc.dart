import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
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
        (failure) => emit(PostsError(failure.message)),
        (post) => emit(PostCreated(post)),
      );
    });

    on<GetFeedEvent>((event, emit) async {
      emit(PostsLoading());
      final result = await getFeedUseCase(
        GetFeedParams(page: event.page, limit: event.limit),
      );
      result.fold(
        (failure) => emit(PostsError(failure.message)),
        (posts) => emit(FeedLoaded(posts)),
      );
    });

    on<GetUserPostsEvent>((event, emit) async {
      emit(PostsLoading());
      final result = await getUserPostsUseCase(
        GetUserPostsParams(
          userId: event.userId,
          page: event.page,
          limit: event.limit,
        ),
      );
      result.fold(
        (failure) => emit(PostsError(failure.message)),
        (posts) => emit(UserPostsLoaded(posts)),
      );
    });

    on<LikePostEvent>((event, emit) async {
      final result = await likePostUseCase(
        LikePostParams(
          postId: event.postId,
          userId: event.userId,
          isLiked: event.isLiked,
        ),
      );
      result.fold(
        (failure) => emit(PostsError(failure.message)),
        (_) => emit(PostLiked(event.postId, !event.isLiked)),
      );
    });

    on<SharePostEvent>((event, emit) async {
      final result = await sharePostUseCase(
        SharePostParams(postId: event.postId),
      );
      result.fold(
        (failure) => emit(PostsError(failure.message)),
        (_) => emit(PostShared(event.postId)),
      );
    });

    on<SubscribeToFeedEvent>((event, emit) {
      repository.getFeedStream().listen((newPosts) {
        add(NewPostsEvent(newPosts));
      });
    });

    on<NewPostsEvent>((event, emit) {
      if (state is FeedLoaded) {
        final currentPosts = (state as FeedLoaded).posts;
        final updatedPosts = [...event.newPosts, ...currentPosts];
        emit(FeedLoaded(updatedPosts));
      }
    });
  }
}
