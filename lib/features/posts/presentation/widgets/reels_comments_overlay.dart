import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comment_input_field.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comments_section.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

/// Bottom-sheet style comments overlay for reels (TikTok / IG style).
/// Use by calling:
///   await ReelsCommentsOverlay.show(context, post, userId);
class ReelsCommentsOverlay extends StatefulWidget {
  final PostEntity post;
  final String userId;

  const ReelsCommentsOverlay({
    super.key,
    required this.post,
    required this.userId,
  });

  /// Helper to show the overlay as a modal bottom sheet.
  static Future<void> show(
    BuildContext context,
    PostEntity post,
    String userId,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
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

  /// Helper to count total comments recursively (same logic as CommentsSection)
  int _countAllComments(List<CommentEntity> comments) {
    int total = 0;
    for (final comment in comments) {
      total++; // count this comment
      if (comment.replies.isNotEmpty) {
        total += _countAllComments(comment.replies); // count all replies
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
        // start taller (user requested increased height)
        final initialFraction = 0.70; // start ~70% of screen height
        final minFraction = 0.40; // allow small peek
        final maxFraction = min(0.92, 0.95); // never truly full-screen

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // prevent dismiss by accidental taps inside sheet area
          child: DraggableScrollableSheet(
            initialChildSize: initialFraction,
            minChildSize: minFraction,
            maxChildSize: maxFraction,
            expand: false,
            builder: (context, scrollController) {
              // AnimatedPadding ensures sheet rises above keyboard when it appears
              final viewInsets = MediaQuery.of(context).viewInsets.bottom;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.only(bottom: viewInsets),
                curve: Curves.easeOut,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        // HEADER with fixed height to prevent tiny overflow
                        SizedBox(
                          height: 72,
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      // Use BlocSelector to reactively update comment count
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
                                              // Fallback to post's static count if not loaded yet
                                              return widget.post.commentsCount;
                                            },
                                            builder: (context, commentCount) {
                                              return Text(
                                                '$commentCount Comment${commentCount != 1 ? 's' : ''}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              );
                                            },
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // Comments list: Expanded so remaining space is used
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: CommentsSection(
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
                              controller:
                                  scrollController, // <- pass controller for smooth drag
                            ),
                          ),
                        ),

                        // Input field pinned to bottom, respects SafeArea and divider
                        SafeArea(
                          top: false,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Theme.of(context).dividerColor,
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
