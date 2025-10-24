import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
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
  PostEntity? _post;
  String? _userId; // This will be set by the BlocSelector in build
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  CommentEntity? _replyingTo;
  bool _subscribedToComments = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    // _loadCurrentUserFromAuth(); // <-- REMOVED: This causes a race condition

    if (widget.post != null) {
      _post = widget.post!;
      // We will subscribe to comments only *after* we confirm the userId in build
    } else {
      // We will fetch the post only *after* we confirm the userId in build
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // This is now called *after* we have a userId
  void _fetchPost() {
    if (_userId != null && widget.post == null && mounted) {
      AppLogger.info(
        'PostDetailsPage: Fetching post ${widget.postId} for user $_userId',
      );
      context.read<PostsBloc>().add(
        GetPostEvent(postId: widget.postId, currentUserId: _userId!),
      );
    }
  }

  // This is now called *after* we have a userId
  void _subscribeToCommentsIfNeeded() {
    if (!_subscribedToComments && mounted && _userId != null) {
      AppLogger.info('Subscribing to comments for post ${widget.postId}');
      context.read<CommentsBloc>().add(SubscribeToCommentsEvent(widget.postId));
      _subscribedToComments = true;
    }
  }

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

  void _postsBlocListener(BuildContext context, PostsState state) {
    if (state is PostLoaded && state.post.id == widget.postId) {
      setState(() => _post = state.post);
      // Now that the post is loaded, subscribe to comments
      _subscribeToCommentsIfNeeded();
    } else if (state is RealtimePostUpdate) {
      _handleRealtimePostUpdate(state);
    } else if (state is PostDeleting && state.postId == widget.postId) {
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
        setState(() => _isDeleting = false);
        Future.microtask(() {
          if (context.mounted) {
            SnackbarUtils.showSuccess(context, 'Post deleted successfully! 🎉');
            context.pop();
          }
        });
      }
    } else if (state is PostsError) {
      AppLogger.error('PostsError in PostDetailsPage: ${state.message}');
      if (_post == null && state.message.contains('not found')) {
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
        setState(() {
          _post = _post!.copyWith(isLiked: state.previousState);
          final corrected = state.previousState
              ? (_post!.likesCount + 1)
              : (_post!.likesCount - 1);
          _post = _post!.copyWith(
            likesCount: corrected.clamp(0, double.infinity).toInt(),
          );
        });
      }
      SnackbarUtils.showError(context, state.message);
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
        setState(() {
          _post = _post!.copyWith(isFavorited: state.previousState);
          final corrected = state.previousState
              ? (_post!.favoritesCount + 1)
              : (_post!.favoritesCount - 1);
          _post = _post!.copyWith(
            favoritesCount: corrected.clamp(0, double.infinity).toInt(),
          );
        });
      }
      SnackbarUtils.showError(context, state.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- THIS IS THE FIX ---
    // Get the userId safely using a BlocSelector
    return BlocSelector<AuthBloc, AuthState, String?>(
      selector: (state) {
        return (state is AuthAuthenticated) ? state.user.id : null;
      },
      builder: (context, userId) {
        // This builder re-runs when userId becomes available
        if (userId == null) {
          // Waiting for AuthBloc to provide user.
          return Scaffold(
            appBar: AppBar(title: Text('Post')),
            body: LoadingIndicator(),
          );
        }

        // --- Logic moved from initState ---
        // We have the userId. Check if this is the first time.
        if (_userId == null) {
          // This is the first build with a valid userId.
          // Set our state and trigger initial fetches.
          _userId = userId;
          if (widget.post == null) {
            _fetchPost();
          } else {
            // If post was passed, we can now safely subscribe
            _subscribeToCommentsIfNeeded();
          }
        }
        // --- End of logic ---

        // The rest of your original build method
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
                    BlocListener<PostsBloc, PostsState>(
                      listener: _postsBlocListener,
                    ),
                    BlocListener<LikesBloc, LikesState>(
                      listener: _likesBlocListener,
                    ),
                    BlocListener<FavoritesBloc, FavoritesState>(
                      listener: _favoritesBlocListener,
                    ),
                  ],
                  // We check _post here. If we are fetching, _post will be null,
                  // and the LoadingIndicator will show, which is correct.
                  child: _post == null
                      ? const LoadingIndicator()
                      : Column(
                          children: [
                            Expanded(
                              child: CustomScrollView(
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
