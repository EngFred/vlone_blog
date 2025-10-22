import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reels_comments_overlay.dart';

class ReelActions extends StatelessWidget {
  final PostEntity post;
  final String userId;
  const ReelActions({super.key, required this.post, required this.userId});

  // Debounce helper to prevent rapid taps
  static const Duration _debounceDuration = Duration(milliseconds: 300);
  static final Map<String, Timer> _debounceTimers = {};

  void _toggleLike(BuildContext context) {
    final postId = post.id;
    final actionKey = 'like_$postId';

    // Cancel existing timer if any
    _debounceTimers[actionKey]?.cancel();

    // Set new timer to dispatch event
    _debounceTimers[actionKey] = Timer(_debounceDuration, () {
      final newLiked = !post.isLiked;
      context.read<PostsBloc>().add(
        LikePostEvent(postId: postId, userId: userId, isLiked: newLiked),
      );
      _debounceTimers.remove(actionKey);
    });
  }

  void _toggleFavorite(BuildContext context) {
    final postId = post.id;
    final actionKey = 'favorite_$postId';

    // Cancel existing timer if any
    _debounceTimers[actionKey]?.cancel();

    // Set new timer to dispatch event
    _debounceTimers[actionKey] = Timer(_debounceDuration, () {
      final newFav = !post.isFavorited;
      context.read<PostsBloc>().add(
        FavoritePostEvent(postId: postId, userId: userId, isFavorited: newFav),
      );
      _debounceTimers.remove(actionKey);
    });
  }

  void _share(BuildContext context) {
    final postId = post.id;
    final actionKey = 'share_$postId';

    // Cancel existing timer if any
    _debounceTimers[actionKey]?.cancel();

    // Set new timer to dispatch event
    _debounceTimers[actionKey] = Timer(_debounceDuration, () {
      context.read<PostsBloc>().add(SharePostEvent(postId: postId));
      _debounceTimers.remove(actionKey);
    });
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
    // FIX: Remove BlocListener - no error toasts for actions
    return Column(
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
