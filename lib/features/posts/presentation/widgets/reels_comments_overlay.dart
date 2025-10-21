import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comment_input_field.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comments_section.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

class ReelsCommentsOverlay extends StatefulWidget {
  final PostEntity post;
  final String userId;
  const ReelsCommentsOverlay({
    super.key,
    required this.post,
    required this.userId,
  });

  @override
  State<ReelsCommentsOverlay> createState() => _ReelsCommentsOverlayState();
}

class _ReelsCommentsOverlayState extends State<ReelsCommentsOverlay> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  CommentEntity? _replyingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommentsBloc>().add(
          SubscribeToCommentsEvent(widget.post.id),
        );
      }
    });
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    context.read<CommentsBloc>().add(
      AddCommentEvent(
        postId: widget.post.id,
        userId: widget.userId,
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
    final screenW = MediaQuery.of(context).size.width;
    final panelWidth = min(350.0, screenW * 0.9);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss overlay
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          // Comments panel (right)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: panelWidth,
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              elevation: 8,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              '${widget.post.commentsCount} Comments',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Comments list (scrollable)
                    Expanded(
                      child: CommentsSection(
                        commentsCount: widget.post.commentsCount,
                        onReply: (comment) {
                          setState(() => _replyingTo = comment);
                          _focusNode.requestFocus();
                        },
                        scrollable: true, // <-- important
                      ),
                    ),

                    // Input
                    CommentInputField(
                      post: widget.post,
                      controller: _commentController,
                      focusNode: _focusNode,
                      replyingTo: _replyingTo,
                      onSend: _addComment,
                      onCancelReply: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
