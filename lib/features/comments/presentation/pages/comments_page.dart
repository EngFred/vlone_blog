import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_item.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_profile_usecase.dart';

class CommentsPage extends StatefulWidget {
  final String postId;

  const CommentsPage({super.key, required this.postId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _commentController = TextEditingController();
  String? _userId;
  Map<String, String> _usernames = {};

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing CommentsPage for post: ${widget.postId}');
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AppLogger.info('Loading current user for CommentsPage');
    try {
      final result = await sl<GetCurrentUserUseCase>()(NoParams());
      result.fold(
        (failure) {
          AppLogger.error('Failed to load current user: ${failure.message}');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
          context.go(Constants.loginRoute);
        },
        (user) {
          AppLogger.info('Current user loaded: ${user.id}');
          setState(() => _userId = user.id);
          if (_userId != null) {
            AppLogger.info('Fetching comments for post: ${widget.postId}');
            context.read<CommentsBloc>().add(GetCommentsEvent(widget.postId));
            AppLogger.info(
              'Subscribing to comments stream for post: ${widget.postId}',
            );
            context.read<CommentsBloc>().add(
              SubscribeToCommentsEvent(widget.postId),
            );
          }
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error loading user: $e', error: e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading user: $e')));
      context.go(Constants.loginRoute);
    }
  }

  Future<String?> _getUsername(String userId) async {
    if (_usernames[userId] != null) {
      AppLogger.info('Username cache hit for user: $userId');
      return _usernames[userId];
    }
    AppLogger.info('Fetching username for user: $userId');
    final result = await sl<GetProfileUseCase>()(userId);
    return result.fold(
      (failure) {
        AppLogger.error(
          'Failed to fetch username for user $userId: ${failure.message}',
        );
        return null;
      },
      (profile) {
        _usernames[userId] = profile.username;
        AppLogger.info(
          'Username fetched: ${profile.username} for user: $userId',
        );
        return profile.username;
      },
    );
  }

  Widget _buildCommentTree(List<CommentEntity> comments, String? parentId) {
    final children = comments
        .where((c) => c.parentCommentId == parentId)
        .toList();
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        return Column(
          children: [
            FutureBuilder<String?>(
              future: _getUsername(child.userId),
              builder: (context, snapshot) {
                return CommentItem(
                  comment: child,
                  parentUsername: parentId != null ? snapshot.data : null,
                );
              },
            ),
            _buildCommentTree(comments, child.id),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const LoadingIndicator();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<CommentsBloc, CommentsState>(
              listener: (context, state) {
                if (state is CommentsLoaded) {
                  AppLogger.info(
                    'Comments loaded with ${state.comments.length} comments for post: ${widget.postId}',
                  );
                } else if (state is CommentsError) {
                  AppLogger.error('Comments load failed: ${state.message}');
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                } else if (state is CommentAdded) {
                  AppLogger.info(
                    'Comment added for post: ${widget.postId} by user: $_userId',
                  );
                }
              },
              builder: (context, state) {
                if (state is CommentsLoading) {
                  return const LoadingIndicator();
                } else if (state is CommentsError) {
                  return EmptyStateWidget(
                    message: state.message,
                    icon: Icons.error_outline,
                    onRetry: () {
                      AppLogger.info(
                        'Retrying comments load for post: ${widget.postId}',
                      );
                      context.read<CommentsBloc>().add(
                        GetCommentsEvent(widget.postId),
                      );
                    },
                    actionText: 'Retry',
                  );
                } else if (state is CommentsLoaded && state.comments.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No comments yet. Be the first to comment!',
                    icon: Icons.chat_bubble_outline,
                  );
                } else if (state is CommentsLoaded) {
                  return _buildCommentTree(state.comments, null);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add comment...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_commentController.text.isNotEmpty) {
                      AppLogger.info(
                        'Adding comment for post: ${widget.postId} by user: $_userId',
                      );
                      context.read<CommentsBloc>().add(
                        AddCommentEvent(
                          postId: widget.postId,
                          userId: _userId!,
                          text: _commentController.text,
                        ),
                      );
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing CommentsPage, cleaning up controller');
    _commentController.dispose();
    super.dispose();
  }
}
