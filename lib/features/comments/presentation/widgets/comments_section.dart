import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_tile.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';

//Used both on post details and reels comments in bottom sheet
class CommentsSection extends StatefulWidget {
  final int? commentsCount;
  final void Function(CommentEntity) onReply;
  final bool scrollable;
  final bool showCountHeader;
  final String currentUserId;
  // final Map<String, GlobalKey> commentKeys; // REMOVED: Retained prop
  // final String? highlightedCommentId; // REMOVED: Retained prop
  final String postId; // Required for dispatching events.

  const CommentsSection({
    super.key,
    this.commentsCount,
    required this.onReply,
    this.scrollable = false,
    this.showCountHeader = true,
    required this.currentUserId,
    // this.controller, // REMOVED: ScrollController
    // required this.commentKeys, // REMOVED
    // this.highlightedCommentId, // REMOVED
    required this.postId, // Pass postId from parent (e.g., PostDetailsPage).
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  bool _hasDispatchedInitial = false; // Prevent double-dispatch on init.

  @override
  void initState() {
    super.initState();
    // Dispatch initial load if scrollable (for bottom sheets/full pages).
    if (widget.scrollable && !_hasDispatchedInitial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<CommentsBloc>().add(
            GetInitialCommentsEvent(widget.postId),
          );
          context.read<CommentsBloc>().add(
            StartCommentsStreamEvent(widget.postId),
          );
          _hasDispatchedInitial = true;
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onRefresh() async {
    context.read<CommentsBloc>().add(RefreshCommentsEvent(widget.postId));
  }

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
          if (commentList.isEmpty && !state.hasMore) {
            return _buildEmpty();
          }

          return _buildCommentList(context, commentList, state);
        }

        if (state is CommentsLoadingMore) {
          return const SizedBox.shrink();
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoading() {
    if (widget.scrollable) {
      return ListView(
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

  Widget _buildLoadingMore() {
    if (widget.scrollable) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: LoadingIndicator(size: 20)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildError(String message) {
    final errorWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: CustomErrorWidget(message: message),
    );

    if (widget.scrollable) {
      return ListView(padding: EdgeInsets.zero, children: [errorWidget]);
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
    if (widget.scrollable) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [const SizedBox(height: 40), emptyWidget],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const SizedBox(height: 40), emptyWidget],
    );
  }

  Widget _buildCommentList(
    BuildContext context,
    List<CommentEntity> comments,
    CommentsLoaded state,
  ) {
    final commentTiles = comments.map((comment) {
      // Use ValueKey now that GlobalKeys are not needed for scrolling/highlighting
      final key = ValueKey(comment.id);

      return CommentTile(
        key: key,
        comment: comment,
        onReply: widget.onReply,
        depth: 0,
        currentUserId: widget.currentUserId,
        // REMOVED: commentKeys: widget.commentKeys,
        // REMOVED: highlightedCommentId: widget.highlightedCommentId,
      );
    }).toList();

    Widget list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: commentTiles,
    );

    if (widget.scrollable) {
      list = RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: commentTiles.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == commentTiles.length) {
              // Load more footer/retry button.
              if (state.loadMoreError != null) {
                return ListTile(
                  title: Text('Error: ${state.loadMoreError}'),
                  trailing: TextButton(
                    onPressed: () => context.read<CommentsBloc>().add(
                      const LoadMoreCommentsEvent(),
                    ),
                    child: const Text('Retry'),
                  ),
                );
              }
              return _buildLoadingMore();
            }
            return commentTiles[index];
          },
        ),
      );
    }

    return list;
  }
}
