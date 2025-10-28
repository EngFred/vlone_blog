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
  final ScrollController? controller;

  const CommentsSection({
    super.key,
    this.commentsCount,
    required this.onReply,
    this.scrollable = false,
    this.showCountHeader = true,
    required this.currentUserId,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      builder: (context, state) {
        if (state is CommentsInitial || state is CommentsLoading) {
          // Pass const SizedBox.shrink() as a placeholder for the removed header
          return _buildLoading(const SizedBox.shrink());
        }

        if (state is CommentsError) {
          return _buildError(const SizedBox.shrink(), state.message);
        }

        if (state is CommentsLoaded) {
          final commentList = state.comments;
          if (commentList.isEmpty) {
            return _buildEmpty(const SizedBox.shrink());
          }

          return _buildCommentList(
            context,
            const SizedBox.shrink(),
            commentList,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  // The 'header' parameter is kept for function signature consistency but is always SizedBox.shrink()
  Widget _buildLoading(Widget header) {
    if (scrollable) {
      return ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [
          // REMOVED: header,
          const SizedBox(height: 40),
          const Center(child: LoadingIndicator()),
          const SizedBox(height: 40),
        ],
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // REMOVED: header,
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: LoadingIndicator(),
          ),
        ),
      ],
    );
  }

  // The 'header' parameter is kept for function signature consistency but is always SizedBox.shrink()
  Widget _buildError(Widget header, String message) {
    if (scrollable) {
      return ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [
          // REMOVED: header,
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 24.0,
            ),
            child: CustomErrorWidget(message: message),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // REMOVED: header,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: CustomErrorWidget(message: message),
        ),
      ],
    );
  }

  // The 'header' parameter is kept for function signature consistency but is always SizedBox.shrink()
  Widget _buildEmpty(Widget header) {
    final emptyWidget = const EmptyStateWidget(
      icon: Icons.chat_bubble_outline,
      message: 'Be the first to comment',
    );
    if (scrollable) {
      return ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [
          // REMOVED: header,
          const SizedBox(height: 40),
          emptyWidget,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // REMOVED: header,
        const SizedBox(height: 40),
        emptyWidget,
      ],
    );
  }

  // The 'header' parameter is kept for function signature consistency but is always SizedBox.shrink()
  Widget _buildCommentList(
    BuildContext context,
    Widget header,
    List<CommentEntity> comments,
  ) {
    if (scrollable) {
      // Logic simplified as there is no header item in the list
      return ListView.builder(
        controller: controller,
        padding: EdgeInsets.zero,
        itemCount: comments.length,
        itemBuilder: (context, index) {
          final comment = comments[index];
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // REMOVED: header,
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
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
}
