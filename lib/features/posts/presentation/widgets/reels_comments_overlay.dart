import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_input_field.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comments_section.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

class ReelsCommentsOverlay extends StatefulWidget {
  final PostEntity post;
  final String userId;

  const ReelsCommentsOverlay({
    super.key,
    required this.post,
    required this.userId,
  });

  static Future<void> show(
    BuildContext context,
    PostEntity post,
    String userId, {
    String? highlightCommentId,
    String? parentCommentId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return SafeArea(
          left: false,
          right: false,
          top: false,
          bottom: false,
          child: ReelsCommentsOverlay(post: post, userId: userId),
        );
      },
    );
  }

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
      if (!mounted) return;
      context.read<CommentsBloc>().add(
        SubscribeToCommentsEvent(widget.post.id),
      );
    });
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    context.read<CommentsBloc>().add(
      AddCommentEvent(
        postId: widget.post.id,
        userId: widget.userId,
        text: text,
        parentCommentId: _replyingTo?.id,
      ),
    );
    _commentController.clear();
    setState(() => _replyingTo = null);
    _focusNode.unfocus();
  }

  int _countAllComments(List<CommentEntity> comments) {
    int total = 0;
    for (final comment in comments) {
      total++;
      if (comment.replies.isNotEmpty) {
        total += _countAllComments(comment.replies);
      }
    }
    return total;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AuthBloc, AuthState, String?>(
      selector: (state) =>
          (state is AuthAuthenticated) ? state.user.profileImageUrl : null,
      builder: (context, userAvatarUrl) {
        final initialFraction = 0.75;
        final minFraction = 0.45;
        final maxFraction = min(0.92, 0.95);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: initialFraction,
            minChildSize: minFraction,
            maxChildSize: maxFraction,
            expand: false,
            builder: (context, scrollController) {
              final viewInsets = MediaQuery.of(context).viewInsets.bottom;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(bottom: viewInsets),
                curve: Curves.easeOut,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.grey[900]!, Colors.black],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Enhanced Header
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[900]!.withOpacity(0.8),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[500],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child:
                                          BlocSelector<
                                            CommentsBloc,
                                            CommentsState,
                                            int
                                          >(
                                            selector: (state) {
                                              if (state is CommentsLoaded) {
                                                return _countAllComments(
                                                  state.comments,
                                                );
                                              }
                                              return widget.post.commentsCount;
                                            },
                                            builder: (context, commentCount) {
                                              return Text(
                                                '$commentCount Comment${commentCount != 1 ? 's' : ''}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              );
                                            },
                                          ),
                                    ),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Colors.grey),

                        // Comments List
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0.0,
                            ),
                            child: CommentsSection(
                              postId: widget.post.id,
                              commentsCount: null,
                              showCountHeader: false,
                              onReply: (comment) {
                                setState(() => _replyingTo = comment);
                                Future.microtask(
                                  () => _focusNode.requestFocus(),
                                );
                              },
                              scrollable: true,
                              currentUserId: widget.userId,
                            ),
                          ),
                        ),

                        // Enhanced Input Field
                        SafeArea(
                          top: false,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey[700]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: CommentInputField(
                              userAvatarUrl: userAvatarUrl,
                              controller: _commentController,
                              focusNode: _focusNode,
                              replyingTo: _replyingTo,
                              onSend: _addComment,
                              onCancelReply: () =>
                                  setState(() => _replyingTo = null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
