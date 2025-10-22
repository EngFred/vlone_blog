import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';

class PostActions extends StatelessWidget {
  final PostEntity post;
  final String userId;
  final VoidCallback? onCommentTap;
  const PostActions({
    super.key,
    required this.post,
    required this.userId,
    this.onCommentTap,
  });
  void _toggleLike(BuildContext context) {
    final newLiked = !post.isLiked;
    context.read<PostsBloc>().add(
      LikePostEvent(postId: post.id, userId: userId, isLiked: newLiked),
    );
  }

  void _toggleFavorite(BuildContext context) {
    final newFav = !post.isFavorited;
    context.read<PostsBloc>().add(
      FavoritePostEvent(postId: post.id, userId: userId, isFavorited: newFav),
    );
  }

  void _share(BuildContext context) {
    context.read<PostsBloc>().add(SharePostEvent(postId: post.id));
  }

  void _handleComment(BuildContext context) {
    if (onCommentTap != null) {
      onCommentTap!();
    } else {
      context.push('${Constants.postDetailsRoute}/${post.id}', extra: post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is PostsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update action')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton(
              icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
              label: post.likesCount.toString(),
              onTap: () => _toggleLike(context),
            ),
            _actionButton(
              icon: Icons.comment,
              label: post.commentsCount.toString(),
              onTap: () => _handleComment(context),
            ),
            _actionButton(
              icon: Icons.share,
              label: post.sharesCount.toString(),
              onTap: () => _share(context),
            ),
            _actionButton(
              icon: post.isFavorited ? Icons.bookmark : Icons.bookmark_border,
              label: post.favoritesCount.toString(),
              onTap: () => _toggleFavorite(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        IconButton(icon: Icon(icon), onPressed: onTap),
        Text(label),
      ],
    );
  }
}
