import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comment_input_field.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comments_section.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_details_content.dart';

class PostDetailsPage extends StatefulWidget {
  final String postId;
  final PostEntity? post;

  const PostDetailsPage({super.key, required this.postId, this.post});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  // Use a nullable PostEntity and rely on its null-state for initial loading
  // This simplifies _hasInitializedPost in many cases.
  PostEntity? _post;
  String? _userId;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  CommentEntity? _replyingTo;
  bool _subscribedToComments = false;
  // bool _hasInitializedPost = false; // Removed: Replaced by checking if _post is null
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    // 1. Get current user immediately
    _loadCurrentUserFromAuth();

    // 2. Decide on initial post state and fetch/subscribe
    if (widget.post != null) {
      _post = widget.post!;
      _subscribeToCommentsIfNeeded();
    } else {
      // If we don't have the post, fetch it.
      _fetchPost();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    // Optional: Cancel comment subscription on dispose if needed,
    // though the BLoC might handle this internally based on its lifecycle.
    // context.read<CommentsBloc>().add(UnsubscribeFromCommentsEvent(widget.postId));
    super.dispose();
  }

  void _loadCurrentUserFromAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _userId = authState.user.id;
      AppLogger.info('Current user from AuthBloc: $_userId');
    } else {
      AppLogger.error('No authenticated user in PostDetailsPage');
      // Consider navigating to a login/error screen if _userId is null
      // and is critical for post viewing (it is, for interactions).
    }
  }

  void _fetchPost() {
    if (_userId != null) {
      context.read<PostsBloc>().add(
        GetPostEvent(postId: widget.postId, currentUserId: _userId!),
      );
    } else {
      AppLogger.error('Cannot fetch post: _userId is null.');
      // Handle the case where auth state wasn't available immediately
      // (The BlocListener handles this better upon PostLoad/Error)
    }
  }

  void _subscribeToCommentsIfNeeded() {
    if (!_subscribedToComments && mounted) {
      context.read<CommentsBloc>().add(SubscribeToCommentsEvent(widget.postId));
      _subscribedToComments = true;
    }
  }

  // Extracted BLoC listener for post updates (Likes, Favorites, Shares)
  void _handleRealtimePostUpdate(RealtimePostUpdate state) {
    if (state.postId == widget.postId &&
        _post != null &&
        mounted &&
        !_isDeleting) {
      setState(() {
        _post = _post!.copyWith(
          likesCount: (state.likesCount ?? _post!.likesCount)
              .clamp(0, double.infinity)
              .toInt(),
          commentsCount: (state.commentsCount ?? _post!.commentsCount)
              .clamp(0, double.infinity)
              .toInt(),
          favoritesCount: (state.favoritesCount ?? _post!.favoritesCount)
              .clamp(0, double.infinity)
              .toInt(),
          sharesCount: (state.sharesCount ?? _post!.sharesCount)
              .clamp(0, double.infinity)
              .toInt(),
        );
      });
    }
  }

  void _addComment() {
    // The check for _post being null is implicitly handled by the UI structure
    // but added for robustness here, though it should never be null if the UI is visible.
    if (_userId == null ||
        _post == null ||
        _commentController.text.trim().isEmpty ||
        _isDeleting)
      return;

    context.read<CommentsBloc>().add(
      AddCommentEvent(
        postId: widget.postId,
        userId: _userId!,
        text: _commentController.text.trim(),
        parentCommentId: _replyingTo?.id,
      ),
    );
    _commentController.clear();
    setState(() => _replyingTo = null);
    _focusNode.unfocus();
  }

  // Extracted the BLoC listener logic for readability
  void _postsBlocListener(BuildContext context, PostsState state) {
    // 1. Initial/Reloaded Post Data
    if (state is PostLoaded && state.post.id == widget.postId) {
      setState(() => _post = state.post);
      _subscribeToCommentsIfNeeded();
    }
    // 2. Interactions (Like/Favorite)
    else if (state is PostLiked &&
        state.postId == widget.postId &&
        _post != null &&
        !_isDeleting) {
      final delta = state.isLiked ? 1 : -1;
      final newCount = (_post!.likesCount + delta)
          .clamp(0, double.infinity)
          .toInt();
      setState(
        () => _post = _post!.copyWith(
          likesCount: newCount,
          isLiked: state.isLiked,
        ),
      );
    } else if (state is PostFavorited &&
        state.postId == widget.postId &&
        _post != null &&
        !_isDeleting) {
      final delta = state.isFavorited ? 1 : -1;
      final newCount = (_post!.favoritesCount + delta)
          .clamp(0, double.infinity)
          .toInt();
      setState(
        () => _post = _post!.copyWith(
          favoritesCount: newCount,
          isFavorited: state.isFavorited,
        ),
      );
    }
    // 3. Realtime Updates
    else if (state is RealtimePostUpdate) {
      _handleRealtimePostUpdate(state);
    }
    // 4. Deletion Lifecycle
    else if (state is PostDeleting && state.postId == widget.postId) {
      if (mounted && !_isDeleting) {
        setState(() => _isDeleting = true);
      }
    } else if (state is PostDeleteError && state.postId == widget.postId) {
      if (mounted) {
        setState(() => _isDeleting = false);
        SnackbarUtils.showError(context, state.message);
      }
    } else if (state is PostDeleted && state.postId == widget.postId) {
      if (mounted) {
        // Clear loading state
        setState(() => _isDeleting = false);

        // Schedule navigation and success toast
        // Use Future.microtask for immediate scheduling in the next event loop,
        // ensuring the UI has a chance to update before navigating away.
        Future.microtask(() {
          if (context.mounted) {
            SnackbarUtils.showSuccess(context, 'Post deleted successfully! 🎉');
            context.pop();
          }
        });
      }
    }
    // 5. General Post Errors (e.g., Post Not Found)
    else if (state is PostsError) {
      AppLogger.error('PostsError in PostDetailsPage: ${state.message}');
      // CRITICAL FIX: If a post is not found or fails to load, show the error
      // and optionally navigate back.
      if (_post == null && state.message.contains('not found')) {
        SnackbarUtils.showError(context, 'Error: ${state.message}');
        Future.microtask(() => context.pop());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user ID is not available (e.g., AuthBloc not ready or error), show loading.
    if (_userId == null) {
      return const Scaffold(body: LoadingIndicator());
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isDeleting) {
          SnackbarUtils.showInfo(
            context,
            'Please wait until the operation completes.',
          );
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Post'),
              centerTitle: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              iconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            body: BlocListener<PostsBloc, PostsState>(
              listener: _postsBlocListener,
              // Show content only when _post is NOT null (initialized)
              child: _post == null
                  ? const LoadingIndicator()
                  : Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: PostDetailsContent(
                                  // The null check for _post is implicitly done by the ternary operator above
                                  post: _post!,
                                  userId: _userId!,
                                  onCommentTap: () {
                                    setState(() => _replyingTo = null);
                                    _focusNode.requestFocus();
                                  },
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: CommentsSection(
                                  commentsCount: _post!.commentsCount,
                                  onReply: (comment) {
                                    setState(() => _replyingTo = comment);
                                    _focusNode.requestFocus();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        CommentInputField(
                          post: _post!,
                          controller: _commentController,
                          focusNode: _focusNode,
                          replyingTo: _replyingTo,
                          onSend: _addComment,
                          onCancelReply: () =>
                              setState(() => _replyingTo = null),
                        ),
                      ],
                    ),
            ),
          ),
          // Full-screen loading overlay
          if (_isDeleting)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Deleting post...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
