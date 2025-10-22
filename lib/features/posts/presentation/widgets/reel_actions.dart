import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reels_comments_overlay.dart';

class ReelActions extends StatelessWidget {
  final PostEntity post;
  final String userId;
  const ReelActions({super.key, required this.post, required this.userId});
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
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => ReelsCommentsOverlay(post: post, userId: userId),
    );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _actionIcon(
            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
            label: post.likesCount.toString(),
            onTap: () => _toggleLike(context),
          ),
          _actionIcon(
            icon: Icons.comment,
            label: post.commentsCount.toString(),
            onTap: () => _handleComment(context),
          ),
          _actionIcon(
            icon: Icons.share,
            label: post.sharesCount.toString(),
            onTap: () => _share(context),
          ),
          _actionIcon(
            icon: post.isFavorited ? Icons.bookmark : Icons.bookmark_border,
            label: post.favoritesCount.toString(),
            onTap: () => _toggleFavorite(context),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white, size: 32),
            onPressed: onTap,
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
