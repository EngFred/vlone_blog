import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_tile.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';

/// A versatile widget for displaying comments associated with a specific post.
///
/// This widget handles the state management logic for fetching, streaming,
/// and displaying comments using the [CommentsBloc]. It supports two primary
/// display modes: a fixed-height, non-scrollable list (e.g., in a sheet)
/// and a full, scrollable list with pull-to-refresh and infinite loading.
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

  /// Dispatches the initial comments fetching and stream events if the
  /// widget is configured to be scrollable (implying it's the main view).
  @override
  void initState() {
    super.initState();
    if (widget.scrollable && !_hasDispatchedInitial) {
      // Deferring dispatch until after the first frame ensures the BLoC is fully available.
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
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

  /// The main build method, routing the UI based on the [CommentsState].
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

        // Returning a placeholder if the state is unhandled.
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
      message: 'No comments yet. Be the first to comment',
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

  /// Builds the actual list of comments. The implementation differs based on
  /// the `scrollable` flag to correctly handle infinite loading.
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

    // --- Non-Scrollable Mode (e.g., in a Bottom Sheet) ---
    Widget list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showCountHeader) _buildCommentsHeader(comments.length),
        ...commentTiles,
      ],
    );

    // --- Scrollable Mode (e.g., in the main post detail page) ---
    if (widget.scrollable) {
      list = RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          // Total items: number of comments + (1 for header if visible) + (1 for loading indicator if hasMore)
          itemCount:
              commentTiles.length +
              (state.hasMore || state.loadMoreError != null ? 1 : 0) +
              (widget.showCountHeader ? 1 : 0),
          itemBuilder: (context, index) {
            if (widget.showCountHeader && index == 0) {
              return _buildCommentsHeader(comments.length);
            }

            // Adjusting the index to account for the optional header
            final contentIndex = widget.showCountHeader ? index - 1 : index;

            // The last item slot is reserved for Load More UI or Load More Error UI
            if (contentIndex == commentTiles.length) {
              if (state.loadMoreError != null) {
                // Displaying error UI with a retry button
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
              // Displaying the loading more indicator
              return _buildLoadingMore();
            }

            // Displaying a regular comment tile
            return commentTiles[contentIndex];
          },
        ),
      );
    }

    return list;
  }
}
