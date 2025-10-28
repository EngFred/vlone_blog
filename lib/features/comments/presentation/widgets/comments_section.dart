import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_tile.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';

//Used both on post details and reels comments in bottom sheet
class CommentsSection extends StatelessWidget {
  final int? commentsCount;
  final void Function(CommentEntity) onReply;
  final bool scrollable;
  final bool showCountHeader;
  final String currentUserId;
  final ScrollController? controller;
  final Map<String, GlobalKey> commentKeys; // Received from parent
  final String? highlightedCommentId;

  const CommentsSection({
    super.key,
    this.commentsCount,
    required this.onReply,
    this.scrollable = false,
    this.showCountHeader = true,
    required this.currentUserId,
    this.controller,
    required this.commentKeys,
    this.highlightedCommentId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      builder: (context, state) {
        if (state is CommentsInitial || state is CommentsLoading) {
          return _buildLoading();
        }

        if (state is CommentsError) {
          return _buildError(state.message);
        }

        if (state is CommentsLoaded) {
          final commentList = state.comments;
          if (commentList.isEmpty) {
            return _buildEmpty();
          }

          return _buildCommentList(context, commentList);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoading() {
    if (scrollable) {
      return ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: const [
          SizedBox(height: 40),
          Center(child: LoadingIndicator()),
          SizedBox(height: 40),
        ],
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: LoadingIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    final errorWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: CustomErrorWidget(message: message),
    );

    if (scrollable) {
      return ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [errorWidget],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [errorWidget],
    );
  }

  Widget _buildEmpty() {
    final emptyWidget = const EmptyStateWidget(
      icon: Icons.chat_bubble_outline,
      message: 'Be the first to comment',
    );
    if (scrollable) {
      return ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [const SizedBox(height: 40), emptyWidget],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const SizedBox(height: 40), emptyWidget],
    );
  }

  Widget _buildCommentList(BuildContext context, List<CommentEntity> comments) {
    final commentTiles = comments.map((comment) {
      // Use GlobalKey if available, else fallback (but now populated)
      final key = commentKeys[comment.id] ?? ValueKey(comment.id);

      return CommentTile(
        key: key,
        comment: comment,
        onReply: onReply,
        depth: 0,
        currentUserId: currentUserId,
        commentKeys: commentKeys, // NEW: Pass the map down for nested tiles
        highlightedCommentId:
            highlightedCommentId, // NEW: Pass down for computation
      );
    }).toList();

    if (scrollable) {
      return ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: commentTiles,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: commentTiles,
    );
  }
}
