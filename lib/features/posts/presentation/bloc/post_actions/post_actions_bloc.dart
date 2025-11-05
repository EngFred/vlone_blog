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
import 'package:vlone_blog_app/core/utils/media_progress_notifier.dart';
part 'post_actions_event.dart';
part 'post_actions_state.dart';

class PostActionsBloc extends Bloc<PostActionsEvent, PostActionsState> {
  final CreatePostUseCase createPostUseCase;
  final GetPostUseCase getPostUseCase;
  final DeletePostUseCase deletePostUseCase;
  final SharePostUseCase sharePostUseCase;

  StreamSubscription<MediaProgress>? _mediaProgressSub;

  PostActionsBloc({
    required this.createPostUseCase,
    required this.getPostUseCase,
    required this.deletePostUseCase,
    required this.sharePostUseCase,
  }) : super(const PostFormState()) {
    // Core action handlers
    on<CreatePostEvent>(_onCreatePost);
    on<GetPostEvent>(_onGetPost);
    on<DeletePostEvent>(_onDeletePost);
    on<SharePostEvent>(_onSharePost);
    on<OptimisticPostUpdate>(_onOptimisticPostUpdate);

    // UI/form handlers
    on<ContentChanged>(_onContentChanged);
    on<MediaSelected>(_onMediaSelected);
    on<ProcessingChanged>(_onProcessingChanged);

    // Subscribe to MediaProgressNotifier to keep processing status in bloc
    _mediaProgressSub = MediaProgressNotifier.stream.listen((progress) {
      // Map notifier progress to ProcessingChanged events
      // Assuming progress has postId if needed; add filter if concurrent
      switch (progress.stage) {
        case MediaProcessingStage.compressing:
          add(
            ProcessingChanged(
              processing: true,
              message: progress.message ?? 'Compressing...',
              percent: progress.percent.clamp(0.0, 100.0),
            ),
          );
          break;
        case MediaProcessingStage.uploading:
          add(
            ProcessingChanged(
              processing: true,
              message: progress.message ?? 'Uploading...',
              percent: null,
            ),
          );
          break;
        case MediaProcessingStage.done:
          add(
            ProcessingChanged(
              processing: false,
              message: 'Done',
              percent: 100.0,
            ),
          );
          break;
        case MediaProcessingStage.error:
          add(
            ProcessingChanged(
              processing: false,
              message: progress.message ?? 'Error',
              percent: null,
            ),
          );
          break;
        case MediaProcessingStage.idle:
          add(
            const ProcessingChanged(
              processing: false,
              message: 'Processing...',
              percent: null,
            ),
          );
          break;
      }
    });
  }

  @override
  Future<void> close() {
    _mediaProgressSub?.cancel();
    _mediaProgressSub = null;
    return super.close();
  }

  // ---------- Event handlers ----------

  Future<void> _onContentChanged(
    ContentChanged event,
    Emitter<PostActionsState> emit,
  ) async {
    final prev = state is PostFormState
        ? (state as PostFormState)
        : const PostFormState();
    final text = event.content;
    final textLength = text.length;
    final isEnabled =
        (text.trim().isNotEmpty || prev.mediaFile != null) &&
        textLength <= prev.maxCharacterLimit;

    final newForm = prev.copyWith(
      content: text,
      currentCharCount: textLength,
      isPostButtonEnabled: isEnabled,
    );
    emit(newForm);
  }

  Future<void> _onMediaSelected(
    MediaSelected event,
    Emitter<PostActionsState> emit,
  ) async {
    final prev = state is PostFormState
        ? (state as PostFormState)
        : const PostFormState();
    final textLength = prev.content.length;
    final isEnabled =
        (prev.content.trim().isNotEmpty || event.file != null) &&
        textLength <= prev.maxCharacterLimit;

    final newForm = prev.copyWith(
      mediaFile: event.file,
      mediaType: event.type,
      isPostButtonEnabled: isEnabled,
    );

    emit(newForm);
  }

  Future<void> _onProcessingChanged(
    ProcessingChanged event,
    Emitter<PostActionsState> emit,
  ) async {
    final prev = state is PostFormState
        ? (state as PostFormState)
        : const PostFormState();
    final newForm = prev.copyWith(
      isProcessing: event.processing,
      processingMessage: event.message ?? prev.processingMessage,
      processingPercent: event.percent ?? prev.processingPercent,
    );
    emit(newForm);

    // If error, also push an error state for UI feedback (optionally).
    if (!event.processing &&
        event.message != null &&
        event.message!.toLowerCase().contains('error')) {
      emit(PostActionError(event.message!));
      // after signalling error, re-emit form state
      emit(newForm);
    }
  }

  Future<void> _onCreatePost(
    CreatePostEvent event,
    Emitter<PostActionsState> emit,
  ) async {
    AppLogger.info('CreatePostEvent triggered');
    final form = state is PostFormState
        ? (state as PostFormState)
        : const PostFormState();

    // Determine content/media to use. Event overrides form if provided.
    final contentToUse =
        event.content ??
        (form.content.trim().isEmpty ? null : form.content.trim());
    final mediaFileToUse = event.mediaFile ?? form.mediaFile;
    final mediaTypeToUse = event.mediaType ?? form.mediaType;

    // Final validation
    if ((contentToUse == null || contentToUse.isEmpty) &&
        mediaFileToUse == null) {
      emit(const PostActionError('Post must have text or media.'));
      // re-emit form state so UI stays in sync
      emit(form);
      return;
    }

    final currentCharCount = contentToUse?.length ?? 0;
    if (currentCharCount > form.maxCharacterLimit) {
      emit(
        PostActionError(
          'Post is too long. Maximum ${form.maxCharacterLimit} characters allowed.',
        ),
      );
      emit(form);
      return;
    }

    emit(const PostActionLoading());
    emit(
      form.copyWith(isProcessing: true, processingMessage: 'Preparing post...'),
    );

    final result = await createPostUseCase(
      CreatePostParams(
        userId: event.userId,
        content: contentToUse,
        mediaFile: mediaFileToUse,
        mediaType: mediaTypeToUse,
      ),
    );

    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Create post failed: $friendlyMessage');
        emit(PostActionError(friendlyMessage));
        // Reset processing and re-emit form state on failure
        emit(
          form.copyWith(isProcessing: false, mediaFile: null, mediaType: null),
        );
      },
      (_) {
        AppLogger.info('Post created successfully.');
        emit(const PostCreatedSuccess());
        emit(const PostFormState());
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
        emit(PostLoaded(post));
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
        emit(PostDeletedSuccess(event.postId));
        emit(const PostActionsInitial());
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
        emit(PostSharedSuccess(event.postId));
        emit(const PostActionsInitial());
      },
    );
  }

  Future<void> _onOptimisticPostUpdate(
    OptimisticPostUpdate event,
    Emitter<PostActionsState> emit,
  ) async {
    final currentPost = event.post;
    final updatedPost = currentPost.copyWith(
      likesCount: (currentPost.likesCount + event.deltaLikes)
          .clamp(0, double.infinity)
          .toInt(),
      favoritesCount: (currentPost.favoritesCount + event.deltaFavorites)
          .clamp(0, double.infinity)
          .toInt(),
      isLiked: event.isLiked ?? currentPost.isLiked,
      isFavorited: event.isFavorited ?? currentPost.isFavorited,
    );

    AppLogger.info(
      'PostActionsBloc: Post ${updatedPost.id} updated optimistically.',
    );
    emit(PostOptimisticallyUpdated(updatedPost));

    if (state is PostLoaded &&
        (state as PostLoaded).post.id == updatedPost.id) {
      emit(PostLoaded(updatedPost));
    }
  }
}
