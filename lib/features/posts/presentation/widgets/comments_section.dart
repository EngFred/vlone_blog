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
  final String currentUserId;
  final ScrollController? controller; // NEW: optional controller

  const CommentsSection({
    super.key,
    this.commentsCount,
    required this.onReply,
    this.scrollable = false,
    this.showCountHeader = true,
    required this.currentUserId,
    this.controller,
  });

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
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
        if (state is CommentsInitial || state is CommentsLoading) {
          if (scrollable) {
            return ListView(
              controller: controller,
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
          if (scrollable) {
            return ListView(
              controller: controller,
              padding: EdgeInsets.zero,
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
                controller: controller,
                padding: EdgeInsets.zero,
                children: [
                  headerWidget,
                  const SizedBox(height: 40),
                  emptyWidget,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [headerWidget, const SizedBox(height: 40), emptyWidget],
            );
          }

          if (scrollable) {
            // When scrollable, we stitch header as first item (if present)
            final baseIndexOffset = showCountHeader ? 1 : 0;
            final totalItems = commentList.length + baseIndexOffset;
            return ListView.builder(
              controller: controller,
              padding: EdgeInsets.zero,
              itemCount: totalItems,
              itemBuilder: (context, index) {
                if (showCountHeader && index == 0) return headerWidget;
                final commentIndex = index - baseIndexOffset;
                final comment = commentList[commentIndex];
                return CommentTile(
                  key: ValueKey(comment.id),
                  comment: comment,
                  onReply: onReply,
                  depth: 0,
                  currentUserId: currentUserId,
                );
              },
            );
          }

          // NON-SCROLLABLE mode (embedded in column)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerWidget,
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
                    currentUserId: currentUserId,
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
