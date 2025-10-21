import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/widgets/comment_tile.dart';

class CommentsSection extends StatelessWidget {
  final int commentsCount;
  final void Function(CommentEntity) onReply;

  /// When true the section itself scrolls (useful for overlays/panels).
  /// When false the section is non-scrolling and expects an outer scroll (details page).
  final bool scrollable;

  const CommentsSection({
    super.key,
    required this.commentsCount,
    required this.onReply,
    this.scrollable = false,
  });

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Comments ($commentsCount)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      builder: (context, state) {
        // --- Loading / Error / Empty states handling
        if (state is CommentsInitial || state is CommentsLoading) {
          if (scrollable) {
            // For scrollable panel, show a centered loading indicator inside ListView
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                const Center(child: LoadingIndicator()),
              ],
            );
          }
          // Non-scrollable: keep layout consistent with the page scroll
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const Center(child: LoadingIndicator()),
            ],
          );
        }

        if (state is CommentsError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: CustomErrorWidget(message: state.message),
              ),
            ],
          );
        }

        if (state is CommentsLoaded) {
          final root = state.rootComments;

          if (root.isEmpty) {
            if (scrollable) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(context),
                  const EmptyStateWidget(
                    icon: Icons.chat_bubble_outline,
                    message: 'Be the first to comment',
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const EmptyStateWidget(
                  icon: Icons.chat_bubble_outline,
                  message: 'Be the first to comment',
                ),
              ],
            );
          }

          // ----- SCROLLABLE MODE: build a single ListView (header as first item)
          if (scrollable) {
            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: root.length + 1, // header + items
              itemBuilder: (context, index) {
                if (index == 0) return _buildHeader(context);
                final comment = root[index - 1];
                return CommentTile(comment: comment, onReply: onReply);
              },
            );
          }

          // ----- NON-SCROLLABLE MODE (used inside a page scroll): keep shrinkWrap list
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: root.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final comment = root[index];
                  return CommentTile(comment: comment, onReply: onReply);
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
