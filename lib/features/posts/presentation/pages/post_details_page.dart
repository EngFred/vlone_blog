import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
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
  late PostEntity _post;
  String? _userId;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  CommentEntity? _replyingTo;
  bool _subscribedToComments = false;
  bool _hasInitializedPost = false;

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _post = widget.post!;
      _hasInitializedPost = true;
      _loadCurrentUserFromAuthAndSubscribe();
    } else {
      _loadCurrentUserFromAuthAndFetchPost();
    }
  }

  void _loadCurrentUserFromAuthAndSubscribe() {
    _loadCurrentUserFromAuth();
    _subscribeToCommentsIfNeeded();
  }

  void _loadCurrentUserFromAuthAndFetchPost() {
    _loadCurrentUserFromAuth();
    if (mounted && _userId != null) {
      context.read<PostsBloc>().add(
        GetPostEvent(widget.postId, viewerUserId: _userId),
      );
    }
  }

  void _loadCurrentUserFromAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _userId = authState.user.id;
      AppLogger.info('Current user from AuthBloc: $_userId');
    } else {
      AppLogger.error('No authenticated user in PostDetailsPage');
      // Handle redirect or error
    }
  }

  void _subscribeToCommentsIfNeeded() {
    if (!_subscribedToComments && mounted) {
      context.read<CommentsBloc>().add(SubscribeToCommentsEvent(widget.postId));
      _subscribedToComments = true;
    }
  }

  void _handleRealtimePostUpdate(RealtimePostUpdate state) {
    if (state.postId == widget.postId && _hasInitializedPost && mounted) {
      setState(() {
        _post = _post.copyWith(
          likesCount: (state.likesCount ?? _post.likesCount)
              .clamp(0, double.infinity)
              .toInt(),
          commentsCount: (state.commentsCount ?? _post.commentsCount)
              .clamp(0, double.infinity)
              .toInt(),
          favoritesCount: (state.favoritesCount ?? _post.favoritesCount)
              .clamp(0, double.infinity)
              .toInt(),
          sharesCount: (state.sharesCount ?? _post.sharesCount)
              .clamp(0, double.infinity)
              .toInt(),
        );
      });
    }
  }

  void _addComment() {
    if (_userId == null || _commentController.text.trim().isEmpty) return;
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

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const Scaffold(body: LoadingIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: BlocListener<PostsBloc, PostsState>(
        listener: (context, state) {
          if (state is PostLoaded && state.post.id == widget.postId) {
            setState(() {
              _post = state.post;
              _hasInitializedPost = true;
            });
            _subscribeToCommentsIfNeeded();
          } else if (state is PostLiked &&
              state.postId == widget.postId &&
              _hasInitializedPost) {
            if (mounted) {
              // FIX: Clamp to prevent negative counts
              final delta = state.isLiked ? 1 : -1;
              final newCount = (_post.likesCount + delta)
                  .clamp(0, double.infinity)
                  .toInt();
              setState(
                () => _post = _post.copyWith(
                  likesCount: newCount,
                  isLiked: state.isLiked,
                ),
              );
            }
          } else if (state is PostFavorited &&
              state.postId == widget.postId &&
              _hasInitializedPost) {
            if (mounted) {
              // FIX: Add handling for PostFavorited with clamping (mirrors PostLiked)
              final delta = state.isFavorited ? 1 : -1;
              final newCount = (_post.favoritesCount + delta)
                  .clamp(0, double.infinity)
                  .toInt();
              setState(
                () => _post = _post.copyWith(
                  favoritesCount: newCount,
                  isFavorited: state.isFavorited,
                ),
              );
            }
          } else if (state is RealtimePostUpdate) {
            _handleRealtimePostUpdate(state);
          } else if (state is PostsError) {
            // FIX: Log silently for interaction errors; no toasts
            AppLogger.error('PostsError in PostDetailsPage: ${state.message}');
          }
        },
        child: _hasInitializedPost
            ? Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: PostDetailsContent(
                            post: _post,
                            userId: _userId!,
                            onCommentTap: () {
                              setState(() => _replyingTo = null);
                              _focusNode.requestFocus();
                            },
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: CommentsSection(
                            commentsCount: _post.commentsCount,
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
                    post: _post,
                    controller: _commentController,
                    focusNode: _focusNode,
                    replyingTo: _replyingTo,
                    onSend: _addComment,
                    onCancelReply: () => setState(() => _replyingTo = null),
                  ),
                ],
              )
            : const LoadingIndicator(),
      ),
    );
  }
}
