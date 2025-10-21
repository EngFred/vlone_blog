import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
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
      _loadCurrentUserAndSubscribe();
    } else {
      _loadCurrentUserAndFetchPost();
    }
  }

  Future<void> _loadCurrentUserAndSubscribe() async {
    await _loadCurrentUser();
    _subscribeToCommentsIfNeeded();
  }

  Future<void> _loadCurrentUserAndFetchPost() async {
    await _loadCurrentUser();
    if (mounted) {
      context.read<PostsBloc>().add(
        GetPostEvent(widget.postId, viewerUserId: _userId),
      );
    }
  }

  Future<void> _loadCurrentUser() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold(
      (failure) =>
          AppLogger.error('Failed to load current user: ${failure.message}'),
      (user) {
        if (mounted) setState(() => _userId = user.id);
      },
    );
  }

  void _subscribeToCommentsIfNeeded() {
    if (!_subscribedToComments && mounted) {
      context.read<CommentsBloc>().add(SubscribeToCommentsEvent(widget.postId));
      _subscribedToComments = true;
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
      body: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
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
                setState(
                  () => _post = _post.copyWith(
                    likesCount: _post.likesCount + (state.isLiked ? 1 : -1),
                    isLiked: state.isLiked,
                  ),
                );
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoriteAdded &&
                  state.postId == widget.postId &&
                  _hasInitializedPost) {
                setState(
                  () => _post = _post.copyWith(
                    favoritesCount:
                        _post.favoritesCount + (state.isFavorited ? 1 : -1),
                    isFavorited: state.isFavorited,
                  ),
                );
              }
            },
          ),
        ],
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
