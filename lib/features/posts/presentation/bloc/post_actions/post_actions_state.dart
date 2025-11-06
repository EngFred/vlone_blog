part of 'post_actions_bloc.dart';

abstract class PostActionsState extends Equatable {
  const PostActionsState();
  @override
  List<Object?> get props => [];
}

class PostActionsInitial extends PostActionsState {
  const PostActionsInitial();
}

class PostActionLoading extends PostActionsState {
  const PostActionLoading();
}

class PostActionError extends PostActionsState {
  final String message;
  const PostActionError(this.message);
  @override
  List<Object?> get props => [message];
}

class PostCreatedSuccess extends PostActionsState {
  const PostCreatedSuccess();
  @override
  List<Object> get props => [];
}

class PostDeletedSuccess extends PostActionsState {
  final String postId;
  const PostDeletedSuccess(this.postId);
  @override
  List<Object?> get props => [postId];
}

class PostSharedSuccess extends PostActionsState {
  final String postId;
  const PostSharedSuccess(this.postId);
  @override
  List<Object?> get props => [postId];
}

class PostLoaded extends PostActionsState {
  final PostEntity post;
  const PostLoaded(this.post);
  @override
  List<Object?> get props => [post];
}

class PostOptimisticallyUpdated extends PostActionsState {
  final PostEntity post;
  const PostOptimisticallyUpdated(this.post);
  @override
  List<Object?> get props => [post];
}

class PostDeleting extends PostActionsState {
  final String postId;
  const PostDeleting(this.postId);
  @override
  List<Object?> get props => [postId];
}

class PostDeleteError extends PostActionsState {
  final String postId;
  final String message;
  const PostDeleteError(this.postId, this.message);
  @override
  List<Object?> get props => [postId, message];
}

class PostFormState extends PostActionsState {
  final String content;
  final File? mediaFile;
  final MediaType? mediaType;
  final bool isProcessing;
  final String processingMessage;
  final double? processingPercent;
  final int currentCharCount;
  final int maxCharacterLimit;
  final int warningThreshold;
  final bool isPostButtonEnabled;

  const PostFormState({
    this.content = '',
    this.mediaFile,
    this.mediaType,
    this.isProcessing = false,
    this.processingMessage = 'Processing...',
    this.processingPercent,
    this.currentCharCount = 0,
    this.maxCharacterLimit = 5000,
    this.warningThreshold = 4500,
    this.isPostButtonEnabled = false,
  });

  bool get isOverLimit => currentCharCount > maxCharacterLimit;
  bool get isNearLimit => currentCharCount >= warningThreshold;

  // Minor cleanup: Check for null
  String get computedUploadMessage {
    if (mediaFile == null || mediaType == null) return 'Uploading post...';
    if (mediaType == MediaType.video) return 'Uploading video...';
    if (mediaType == MediaType.image) return 'Uploading image...';
    return 'Uploading...';
  }

  // Sentinel used to differentiate "no change" from explicit `null`
  static const Object _noChange = Object();

  /// copyWith supports explicit clearing by passing null for nullable fields.
  PostFormState copyWith({
    String? content,
    // Object? is used here to enable the "no change" sentinel logic.
    Object? mediaFile = _noChange,
    Object? mediaType = _noChange,
    bool? isProcessing,
    String? processingMessage,
    double? processingPercent,
    int? currentCharCount,
    int? maxCharacterLimit,
    int? warningThreshold,
    bool? isPostButtonEnabled,
  }) {
    final File? computedMediaFile = identical(mediaFile, _noChange)
        ? this.mediaFile
        : mediaFile as File?;

    // Cast to MediaType? is correct here to assign to the final MediaType? field
    final MediaType? computedMediaType = identical(mediaType, _noChange)
        ? this.mediaType
        : mediaType as MediaType?;

    return PostFormState(
      content: content ?? this.content,
      mediaFile: computedMediaFile,
      mediaType: computedMediaType,
      isProcessing: isProcessing ?? this.isProcessing,
      processingMessage: processingMessage ?? this.processingMessage,
      processingPercent: processingPercent ?? this.processingPercent,
      currentCharCount: currentCharCount ?? this.currentCharCount,
      maxCharacterLimit: maxCharacterLimit ?? this.maxCharacterLimit,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      isPostButtonEnabled: isPostButtonEnabled ?? this.isPostButtonEnabled,
    );
  }

  @override
  List<Object?> get props => [
    content,
    mediaFile?.path,
    mediaType,
    isProcessing,
    processingMessage,
    processingPercent,
    currentCharCount,
    maxCharacterLimit,
    warningThreshold,
    isPostButtonEnabled,
  ];
}
