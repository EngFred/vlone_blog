import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/domain/entities/user_entity.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_input_field.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comments_section.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_details_content.dart';

class PostDetailsPage extends StatefulWidget {
  final String postId;
  final PostEntity? post;
  final String? highlightCommentId;
  final String? parentCommentId;

  const PostDetailsPage({
    super.key,
    required this.postId,
    this.post,
    this.highlightCommentId,
    this.parentCommentId,
  });

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  PostEntity? _post;
  String? _userId;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  CommentEntity? _replyingTo;
  bool _subscribedToComments = false;
  bool _isDeleting = false;

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _commentKeys = {};
  String? _commentToScrollId;
  String? _highlightedCommentId;

  @override
  void initState() {
    super.initState();
    if (widget.post != null) _post = widget.post;
    _commentToScrollId = widget.highlightCommentId;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchPost() {
    if (_userId != null && widget.post == null && mounted) {
      AppLogger.info(
        'PostDetailsPage: Fetching post ${widget.postId} for user $_userId using PostActionsBloc',
      );
      context.read<PostActionsBloc>().add(
        GetPostEvent(postId: widget.postId, currentUserId: _userId!),
      );
    }
  }

  void _subscribeToCommentsIfNeeded() {
    if (!_subscribedToComments && mounted && _userId != null) {
      AppLogger.info('Subscribing to comments for post ${widget.postId}');
      context.read<CommentsBloc>().add(SubscribeToCommentsEvent(widget.postId));
      _subscribedToComments = true;
    }
  }

  void _scrollToComment(String commentId) {
    if (_highlightedCommentId == commentId) return;

    final key = _commentKeys[commentId];
    if (key == null || key.currentContext == null) {
      AppLogger.warning(
        'PostDetailsPage: Cannot scroll, key not found or context is null for ID $commentId',
      );
      return;
    }

    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    ).then((_) {
      if (mounted) {
        setState(() {
          _highlightedCommentId = commentId;
          _commentToScrollId = null;
        });
        AppLogger.info(
          'PostDetailsPage: Scrolled to and highlighted comment $commentId.',
        );
      }
    });
  }

  void _addComment() {
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

  void _postActionsBlocListener(BuildContext context, PostActionsState state) {
    if (state is PostLoaded && state.post.id == widget.postId) {
      setState(() => _post = state.post);
      _subscribeToCommentsIfNeeded();
    } else if (state is PostDeleting && state.postId == widget.postId) {
      if (mounted && !_isDeleting) setState(() => _isDeleting = true);
    } else if (state is PostDeleteError && state.postId == widget.postId) {
      if (mounted) {
        setState(() => _isDeleting = false);
        SnackbarUtils.showError(context, state.message);
      }
    } else if (state is PostDeletedSuccess && state.postId == widget.postId) {
      if (mounted) {
        setState(() => _isDeleting = false);
        Future.microtask(() {
          if (context.mounted) {
            SnackbarUtils.showSuccess(context, 'Post deleted successfully! 🎉');
            context.pop();
          }
        });
      }
    } else if (state is PostActionError) {
      AppLogger.error('PostActionError in PostDetailsPage: ${state.message}');
      if (_post == null && state.message.toLowerCase().contains('not found')) {
        SnackbarUtils.showError(context, 'Error: ${state.message}');
        Future.microtask(() => context.pop());
      }
    }
  }

  void _likesBlocListener(BuildContext context, LikesState state) {
    if (state is LikeUpdated &&
        state.postId == widget.postId &&
        _post != null &&
        !_isDeleting) {
      final delta = state.isLiked ? 1 : -1;
      setState(() {
        _post = _post!.copyWith(
          likesCount: (_post!.likesCount + delta)
              .clamp(0, double.infinity)
              .toInt(),
          isLiked: state.isLiked,
        );
      });
    } else if (state is LikeError && state.postId == widget.postId) {
      if (_post != null && mounted) {
        // Revert local optimistic changes
        setState(() {
          _post = _post!.copyWith(isLiked: state.previousState);
          final corrected = state.previousState
              ? (_post!.likesCount + 1)
              : (_post!.likesCount - 1);
          _post = _post!.copyWith(
            likesCount: corrected.clamp(0, double.infinity).toInt(),
          );
        });
        SnackbarUtils.showError(context, state.message);
      }
    }
  }

  void _favoritesBlocListener(BuildContext context, FavoritesState state) {
    if (state is FavoriteUpdated &&
        state.postId == widget.postId &&
        _post != null &&
        !_isDeleting) {
      final delta = state.isFavorited ? 1 : -1;
      setState(() {
        _post = _post!.copyWith(
          favoritesCount: (_post!.favoritesCount + delta)
              .clamp(0, double.infinity)
              .toInt(),
          isFavorited: state.isFavorited,
        );
      });
    } else if (state is FavoriteError && state.postId == widget.postId) {
      if (_post != null && mounted) {
        // Revert local optimistic changes
        setState(() {
          _post = _post!.copyWith(isFavorited: state.previousState);
          final corrected = state.previousState
              ? (_post!.favoritesCount + 1)
              : (_post!.favoritesCount - 1);
          _post = _post!.copyWith(
            favoritesCount: corrected.clamp(0, double.infinity).toInt(),
          );
        });
        SnackbarUtils.showError(context, state.message);
      }
    }
  }

  // Recursively assign GlobalKeys to all comments and their replies (Unchanged)
  void _assignCommentKeys(List<CommentEntity> comments) {
    for (var comment in comments) {
      if (!_commentKeys.containsKey(comment.id)) {
        _commentKeys[comment.id] = GlobalKey();
      }
      _assignCommentKeys(comment.replies);
    }
  }

  // Check if a comment ID is in the subtree of a given comment (Unchanged)
  bool _isInSubtree(String id, CommentEntity comment) {
    if (comment.id == id) return true;
    for (var reply in comment.replies) {
      if (_isInSubtree(id, reply)) return true;
    }
    return false;
  }

  // Find the root (top-level) comment ID that contains the target ID in its subtree (Unchanged)
  String? _findRootCommentId(String targetId, List<CommentEntity> comments) {
    for (var comment in comments) {
      if (_isInSubtree(targetId, comment)) {
        return comment.id;
      }
    }
    return null;
  }

  void _commentsBlocListener(BuildContext context, CommentsState state) {
    if (state is CommentsLoaded) {
      _assignCommentKeys(state.comments);

      if (_commentToScrollId != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;

          final targetId = _commentToScrollId!;
          final rootId = _findRootCommentId(targetId, state.comments);

          if (rootId != null && rootId != targetId) {
            final rootKey = _commentKeys[rootId];
            if (rootKey != null && rootKey.currentState != null) {
              // Assuming CommentTileState has a public method or public state for expansion
              (rootKey.currentState as dynamic).expandReplies();
            }
          }

          if (_commentKeys.containsKey(targetId)) {
            _scrollToComment(targetId);
          } else {
            AppLogger.warning(
              'PostDetailsPage: Key not found for $targetId after assignment',
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AuthBloc, AuthState, UserEntity?>(
      selector: (state) => (state is AuthAuthenticated) ? state.user : null,
      builder: (context, user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Post')),
            body: const LoadingIndicator(),
          );
        }

        if (_userId == null) {
          _userId = user.id;
          if (widget.post == null) {
            _fetchPost();
          } else {
            _subscribeToCommentsIfNeeded();
          }
        }

        if (!_focusNode.hasFocus &&
            _highlightedCommentId != null &&
            _commentToScrollId == null) {
          Future.microtask(() => setState(() => _highlightedCommentId = null));
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
                body: MultiBlocListener(
                  listeners: [
                    BlocListener<PostActionsBloc, PostActionsState>(
                      listener: _postActionsBlocListener,
                    ),
                    BlocListener<LikesBloc, LikesState>(
                      listener: _likesBlocListener,
                    ),
                    BlocListener<FavoritesBloc, FavoritesState>(
                      listener: _favoritesBlocListener,
                    ),
                    BlocListener<CommentsBloc, CommentsState>(
                      listener: _commentsBlocListener,
                    ),
                  ],
                  child: _post == null
                      ? const LoadingIndicator()
                      : Column(
                          children: [
                            Expanded(
                              child: CustomScrollView(
                                controller: _scrollController,
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: PostDetailsContent(
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
                                      currentUserId: _userId!,
                                      onReply: (comment) {
                                        setState(() => _replyingTo = comment);
                                        _focusNode.requestFocus();
                                      },
                                      commentKeys: _commentKeys,
                                      highlightedCommentId:
                                          _highlightedCommentId,
                                      postId: widget.postId,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CommentInputField(
                              userAvatarUrl: user.profileImageUrl,
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
      },
    );
  }
}
