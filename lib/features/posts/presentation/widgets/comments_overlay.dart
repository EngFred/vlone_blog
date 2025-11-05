import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_input_field.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comments_section.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

class CommentsOverlay extends StatefulWidget {
  final PostEntity post;
  final String userId;
  const CommentsOverlay({super.key, required this.post, required this.userId});

  static Future<void> show(
    BuildContext context,
    PostEntity post,
    String userId,
  ) {
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
          child: CommentsOverlay(post: post, userId: userId),
        );
      },
    );
  }

  @override
  State<CommentsOverlay> createState() => _CommentsOverlayState();
}

class _CommentsOverlayState extends State<CommentsOverlay> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  CommentEntity? _replyingTo;

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
    final theme = Theme.of(context); // Get the theme here
    return BlocSelector<AuthBloc, AuthState, (String?, String?)>(
      selector: (state) => state is AuthAuthenticated
          ? (state.user.username, state.user.profileImageUrl)
          : (null, null),
      builder: (context, userInfo) {
        final (username, avatarUrl) = userInfo;
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
                    // FIX: Replaced hardcoded dark gradient with theme-aware color
                    color: theme.colorScheme.surface,
                    child: Column(
                      children: [
                        // Enhanced Header
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            // FIX: Replaced Colors.grey[900]! with theme.colorScheme.surface
                            color: theme.colorScheme.surface,
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
                                  // FIX: Replaced Colors.grey[500] with theme-aware color
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
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
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      // FIX: Ensure text color is theme-aware
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              );
                                            },
                                          ),
                                    ),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        // FIX: Replaced Colors.grey[800] with theme-aware color
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          // FIX: Ensure icon color is theme-aware
                                          color: theme.colorScheme.onSurface,
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
                        // FIX: Replaced Colors.grey with theme.colorScheme.outline
                        Divider(
                          height: 1,
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
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
                              // FIX: Replaced Colors.grey[900] with theme.colorScheme.surface
                              color: theme.colorScheme.surface,
                              border: Border(
                                top: BorderSide(
                                  // FIX: Replaced Colors.grey[700]! with theme.colorScheme.outline
                                  color: theme.colorScheme.outline.withOpacity(
                                    0.5,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: CommentInputField(
                              userAvatarUrl: avatarUrl,
                              controller: _commentController,
                              focusNode: _focusNode,
                              replyingTo: _replyingTo,
                              onSend: () {
                                if (_commentController.text.trim().isNotEmpty) {
                                  context.read<CommentsBloc>().add(
                                    AddCommentEvent(
                                      postId: widget.post.id,
                                      userId: widget.userId,
                                      text: _commentController.text.trim(),
                                      parentCommentId: _replyingTo?.id,
                                      username: username,
                                      avatarUrl: avatarUrl,
                                    ),
                                  );
                                  _commentController.clear();
                                  setState(() => _replyingTo = null);
                                  _focusNode.unfocus();
                                }
                              },
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
