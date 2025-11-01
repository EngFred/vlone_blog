import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_tile.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';

class CommentsSection extends StatefulWidget {
  final int? commentsCount;
  final void Function(CommentEntity) onReply;
  final bool scrollable;
  final bool showCountHeader;
  final String currentUserId;
  final String postId;

  const CommentsSection({
    super.key,
    this.commentsCount,
    required this.onReply,
    this.scrollable = false,
    this.showCountHeader = true,
    required this.currentUserId,
    required this.postId,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  bool _hasDispatchedInitial = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _onRefresh() async {
    context.read<CommentsBloc>().add(RefreshCommentsEvent(widget.postId));
  }

  Widget _buildCommentsHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Comments',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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

        // Note: CommentsLoadingMore is handled *inside* _buildCommentList
        // as an item, so we don't need a top-level check for it.
        // We just need to make sure we don't return shrink() if
        // the state is CommentsLoaded.

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoading() {
    if (widget.scrollable) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          if (widget.showCountHeader) _buildCommentsHeader(0),
          const SizedBox(height: 40),
          Center(child: LoadingIndicator(size: 24)),
          const SizedBox(height: 40),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showCountHeader) _buildCommentsHeader(0),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: LoadingIndicator(size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingMore() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          children: [
            LoadingIndicator(size: 20),
            const SizedBox(height: 8),
            Text(
              'Loading more comments...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    final errorWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: CustomErrorWidget(message: message),
    );

    if (widget.scrollable) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          if (widget.showCountHeader) _buildCommentsHeader(0),
          errorWidget,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showCountHeader) _buildCommentsHeader(0),
        errorWidget,
      ],
    );
  }

  Widget _buildEmpty() {
    final emptyWidget = EmptyStateWidget(
      icon: Icons.chat_bubble_outline,
      message: 'No comments yet',
    );

    if (widget.scrollable) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (widget.showCountHeader) _buildCommentsHeader(0),
            const SizedBox(height: 40),
            emptyWidget,
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showCountHeader) _buildCommentsHeader(0),
        const SizedBox(height: 40),
        emptyWidget,
      ],
    );
  }

  Widget _buildCommentList(
    BuildContext context,
    List<CommentEntity> comments,
    CommentsLoaded state,
  ) {
    final commentTiles = comments.map((comment) {
      return CommentTile(
        key: ValueKey(comment.id),
        comment: comment,
        onReply: widget.onReply,
        depth: 0,
        currentUserId: widget.currentUserId,
      );
    }).toList();

    Widget list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showCountHeader) _buildCommentsHeader(comments.length),
        ...commentTiles,
      ],
    );

    if (widget.scrollable) {
      list = RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount:
              commentTiles.length +
              (state.hasMore ? 1 : 0) +
              (widget.showCountHeader ? 1 : 0), // <--- FIX 1: Corrected logic
          itemBuilder: (context, index) {
            if (widget.showCountHeader && index == 0) {
              return _buildCommentsHeader(comments.length);
            }

            final contentIndex = widget.showCountHeader ? index - 1 : index;

            if (contentIndex == commentTiles.length) {
              // This item is the "load more" or error slot.
              // It is only built if state.hasMore is true.
              if (state.loadMoreError != null) {
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Failed to load more comments',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => context.read<CommentsBloc>().add(
                          LoadMoreCommentsEvent(widget.postId),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                );
              }
              // This is safe because itemCount is zero if hasMore is false
              return _buildLoadingMore();
            }

            // This is a regular comment tile
            // The RangeError was here because 'contentIndex' could be out of bounds
            // but the itemCount fix resolves this.
            return commentTiles[contentIndex];
          },
        ),
      );
    }

    return list;
  }
}
