import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_tile.dart';

class CommentsSection extends StatelessWidget {
  final int? commentsCount;
  final void Function(CommentEntity) onReply;
  final bool scrollable;
  final bool showCountHeader;

  const CommentsSection({
    super.key,
    this.commentsCount,
    required this.onReply,
    this.scrollable = false,
    this.showCountHeader = true,
  });

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    // Fallback text if count is null
    final countText = commentsCount != null
        ? 'Comments ($commentsCount)'
        : 'Comments';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Text(
        countText,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerWidget = showCountHeader
        ? _buildHeader(context)
        : const SizedBox.shrink();

    return BlocBuilder<CommentsBloc, CommentsState>(
      builder: (context, state) {
        // --- Loading / Error / Empty states handling
        if (state is CommentsInitial || state is CommentsLoading) {
          if (scrollable) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                headerWidget,
                const SizedBox(height: 40),
                const Center(child: LoadingIndicator()),
                const SizedBox(height: 40),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerWidget,
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: LoadingIndicator(),
                ),
              ),
            ],
          );
        }

        if (state is CommentsError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerWidget,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                child: CustomErrorWidget(message: state.message),
              ),
            ],
          );
        }

        if (state is CommentsLoaded) {
          final commentList = state.comments;

          if (commentList.isEmpty) {
            final emptyWidget = const EmptyStateWidget(
              icon: Icons.chat_bubble_outline,
              message: 'Be the first to comment',
            );

            if (scrollable) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  headerWidget, // Use the conditional widget
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: emptyWidget,
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerWidget,
                Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: emptyWidget,
                ),
              ],
            );
          }

          // ----- SCROLLABLE MODE: build a single ListView
          if (scrollable) {
            return ListView.builder(
              padding: EdgeInsets.zero,
              // Adjust itemCount based on whether the header is shown
              itemCount: commentList.length + (showCountHeader ? 1 : 0),
              itemBuilder: (context, index) {
                // Adjust index check based on whether the header is the first item
                if (showCountHeader && index == 0) return headerWidget;

                final commentIndex = showCountHeader ? index - 1 : index;
                final comment = commentList[commentIndex];

                return CommentTile(
                  key: ValueKey(comment.id),
                  comment: comment,
                  onReply: onReply,
                  depth: 0,
                );
              },
            );
          }

          // ----- NON-SCROLLABLE MODE
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerWidget, // Use the conditional widget
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: commentList.length,
                itemBuilder: (context, index) {
                  final comment = commentList[index];
                  return CommentTile(
                    key: ValueKey(comment.id),
                    comment: comment,
                    onReply: onReply,
                    depth: 0,
                  );
                },
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
