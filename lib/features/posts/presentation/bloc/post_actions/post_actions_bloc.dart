import 'dart:async';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/delete_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/share_post_usecase.dart';

part 'post_actions_event.dart';
part 'post_actions_state.dart';

class PostActionsBloc extends Bloc<PostActionsEvent, PostActionsState> {
  final CreatePostUseCase createPostUseCase;
  final GetPostUseCase getPostUseCase;
  final DeletePostUseCase deletePostUseCase;
  final SharePostUseCase sharePostUseCase;

  PostActionsBloc({
    required this.createPostUseCase,
    required this.getPostUseCase,
    required this.deletePostUseCase,
    required this.sharePostUseCase,
    // required this.realtimeService,
  }) : super(const PostActionsInitial()) {
    on<CreatePostEvent>(_onCreatePost);
    on<GetPostEvent>(_onGetPost);
    on<DeletePostEvent>(_onDeletePost);
    on<SharePostEvent>(_onSharePost);
    // ✅ ADDED: Optimistic Post Update Handler
    on<OptimisticPostUpdate>(_onOptimisticPostUpdate);
  }

  // ... (previous handlers: _onCreatePost, _onGetPost, _onDeletePost, _onSharePost) ...

  // ℹ️ Note: Placing handlers here for brevity. In your file, they should be in order.

  Future<void> _onCreatePost(
    CreatePostEvent event,
    Emitter<PostActionsState> emit,
  ) async {
    AppLogger.info('CreatePostEvent triggered');
    emit(const PostActionLoading());
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
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Create post failed: $friendlyMessage');
        emit(PostActionError(friendlyMessage));
      },
      (post) {
        AppLogger.info('Post created successfully: ${post.id}');
        emit(PostCreatedSuccess(post)); // UI will listen for this
        emit(const PostActionsInitial()); // Reset state
      },
    );
  }

  Future<void> _onGetPost(
    GetPostEvent event,
    Emitter<PostActionsState> emit,
  ) async {
    AppLogger.info('GetPostEvent for post: ${event.postId}');
    emit(const PostActionLoading());
    final result = await getPostUseCase(
      GetPostParams(postId: event.postId, currentUserId: event.currentUserId),
    );
    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Get post failed: $friendlyMessage');
        emit(PostActionError(friendlyMessage));
      },
      (post) {
        AppLogger.info('Post loaded: ${post.id}');
        emit(PostLoaded(post)); // Persistent state for detail screen
      },
    );
  }

  Future<void> _onDeletePost(
    DeletePostEvent event,
    Emitter<PostActionsState> emit,
  ) async {
    AppLogger.info('DeletePostEvent triggered for post: ${event.postId}');
    emit(PostDeleting(event.postId));
    final result = await deletePostUseCase(
      DeletePostParams(postId: event.postId),
    );
    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Delete post failed: $friendlyMessage');
        emit(PostDeleteError(event.postId, friendlyMessage));
      },
      (_) {
        AppLogger.info('Post deleted successfully: ${event.postId}');
        emit(PostDeletedSuccess(event.postId)); // UI will listen for this
        emit(const PostActionsInitial()); // Reset state
      },
    );
  }

  Future<void> _onSharePost(
    SharePostEvent event,
    Emitter<PostActionsState> emit,
  ) async {
    AppLogger.info('SharePostEvent triggered for post: ${event.postId}');
    emit(const PostActionLoading());
    final result = await sharePostUseCase(
      SharePostParams(postId: event.postId),
    );
    result.fold(
      (failure) {
        AppLogger.error('Share post failed: ${failure.message}');
        emit(PostActionError(failure.message));
      },
      (_) {
        AppLogger.info('Post shared successfully');
        emit(PostSharedSuccess(event.postId)); // UI will listen for this
        emit(const PostActionsInitial()); // Reset state
      },
    );
  }

  // ✅ ADDED: Handler for optimistic updates
  Future<void> _onOptimisticPostUpdate(
    OptimisticPostUpdate event,
    Emitter<PostActionsState> emit,
  ) async {
    // Optimistic update should only happen if we have a PostLoaded state currently,
    // as PostActionsBloc is acting like the detail screen's source of truth.
    if (state is PostLoaded && (state as PostLoaded).post.id == event.postId) {
      final currentPost = (state as PostLoaded).post;

      final updatedPost = currentPost.copyWith(
        likesCount: (currentPost.likesCount + event.deltaLikes)
            .clamp(0, double.infinity)
            .toInt(),
        favoritesCount: (currentPost.favoritesCount + event.deltaFavorites)
            .clamp(0, double.infinity)
            .toInt(),
        // Only update the boolean state if it was explicitly passed
        isLiked: event.isLiked ?? currentPost.isLiked,
        isFavorited: event.isFavorited ?? currentPost.isFavorited,
      );

      AppLogger.info('Post ${event.postId} updated optimistically.');

      // Emit the updated state
      emit(PostOptimisticallyUpdated(updatedPost));
      // Revert to PostLoaded state to maintain the persistent data state for the screen
      emit(PostLoaded(updatedPost));
    } else {
      AppLogger.warning(
        'PostActionsBloc: OptimisticPostUpdate ignored for ${event.postId} - PostLoaded state not found.',
      );
    }
  }
}
