import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
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
import 'package:vlone_blog_app/features/posts/presentation/widgets/details/post_details_content.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.post != null) _post = widget.post;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
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

  void _addComment() {
    if (_userId == null ||
        _post == null ||
        _commentController.text.trim().isEmpty ||
        _isDeleting) {
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AuthBloc, AuthState, UserEntity?>(
      selector: (state) => (state is AuthAuthenticated) ? state.user : null,
      builder: (context, user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Post'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoadingIndicator(size: 32),
                  const SizedBox(height: 16),
                  Text(
                    'Loading post...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
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
                // Setting this to 'false' stops the Scaffold from shrinking.
                resizeToAvoidBottomInset: false,
                backgroundColor: Theme.of(context).colorScheme.surface,
                appBar: AppBar(
                  title: const Text(
                    'Post',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  centerTitle: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 4,
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
                  ],
                  child: _post == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              LoadingIndicator(size: 32),
                              const SizedBox(height: 16),
                              Text(
                                'Loading post content...',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                              ),
                            ],
                          ),
                        )
                      : SafeArea(
                          top: false,
                          bottom: true,
                          child: Column(
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
                                        currentUserId: _userId!,
                                        onReply: (comment) {
                                          setState(() => _replyingTo = comment);
                                          _focusNode.requestFocus();
                                        },
                                        postId: widget.postId,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(
                                    context,
                                  ).viewInsets.bottom,
                                ),
                                child: CommentInputField(
                                  userAvatarUrl: user.profileImageUrl,
                                  controller: _commentController,
                                  focusNode: _focusNode,
                                  replyingTo: _replyingTo,
                                  onSend: _addComment,
                                  onCancelReply: () =>
                                      setState(() => _replyingTo = null),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              if (_isDeleting)
                ModalBarrier(
                  color: Colors.black.withOpacity(0.7),
                  dismissible: false,
                ),
              if (_isDeleting)
                Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoadingIndicator(size: 32),
                        const SizedBox(height: 16),
                        Text(
                          'Deleting post...',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
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
