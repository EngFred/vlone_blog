import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
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
  Map<String, String> _usernames = {}; // Cache usernames

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold((failure) => null, (user) => setState(() => _userId = user.id));
    if (_userId != null) {
      context.read<CommentsBloc>().add(GetCommentsEvent(widget.postId));
      context.read<CommentsBloc>().add(SubscribeToCommentsEvent(widget.postId));
    }
  }

  Future<String?> _getUsername(String userId) async {
    if (_usernames[userId] != null) return _usernames[userId];
    final result = await sl<GetProfileUseCase>()(userId);
    return result.fold((failure) => null, (profile) {
      _usernames[userId] = profile.username;
      return profile.username;
    });
  }

  Widget _buildCommentTree(List<CommentEntity> comments, String? parentId) {
    final children = comments
        .where((c) => c.parentCommentId == parentId)
        .toList();
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
    if (_userId == null) return const LoadingIndicator();

    return BlocProvider<CommentsBloc>(
      create: (_) => sl<CommentsBloc>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<CommentsBloc, CommentsState>(
                builder: (context, state) {
                  if (state is CommentsLoading) {
                    return const LoadingIndicator();
                  } else if (state is CommentsLoaded) {
                    return _buildCommentTree(
                      state.comments,
                      null,
                    ); // Build threaded tree
                  } else if (state is CommentsError) {
                    return Center(child: Text(state.message));
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
                        context.read<CommentsBloc>().add(
                          AddCommentEvent(
                            postId: widget.postId,
                            userId: _userId!,
                            text: _commentController.text,
                            // parentCommentId for replies (add logic for reply button in CommentItem)
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
      ),
    );
  }
}
