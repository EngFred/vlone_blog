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

// --- Success States ---
// These are transient. The UI listens for them and then
// the BLoC should ideally return to Initial.

class PostCreatedSuccess extends PostActionsState {
  final PostEntity post;
  const PostCreatedSuccess(this.post);
  @override
  List<Object?> get props => [post];
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

// --- Loaded State (for GetPost) ---
// This is a persistent state for a detail screen.
class PostLoaded extends PostActionsState {
  final PostEntity post;
  const PostLoaded(this.post);
  @override
  List<Object?> get props => [post];
}

// ✅ ADDED: State for optimistic updates
// This is the new state that the PostActions widget should listen to.
class PostOptimisticallyUpdated extends PostActionsState {
  final PostEntity post;
  const PostOptimisticallyUpdated(this.post);
  @override
  List<Object?> get props => [post];
}

// --- Specific Action States (Optional but good for UI) ---

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
