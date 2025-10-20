import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:go_router/go_router.dart';

class PostActions extends StatefulWidget {
  final PostEntity post;
  final String userId;
  const PostActions({super.key, required this.post, required this.userId});

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  late bool _isLiked;
  late int _likesCount;
  late bool _isFavorited;
  late int _favoritesCount;
  late int _sharesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _isFavorited = widget.post.isFavorited;
    _favoritesCount = widget.post.favoritesCount;
    _sharesCount = widget.post.sharesCount;
  }

  @override
  void didUpdateWidget(covariant PostActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likesCount;
      _isFavorited = widget.post.isFavorited;
      _favoritesCount = widget.post.favoritesCount;
      _sharesCount = widget.post.sharesCount;
    }
  }

  void _toggleLike() {
    final newLiked = !_isLiked;
    setState(() {
      _isLiked = newLiked;
      _likesCount += newLiked ? 1 : -1;
    });
    context.read<PostsBloc>().add(
      LikePostEvent(
        postId: widget.post.id,
        userId: widget.userId,
        isLiked: newLiked,
      ),
    );
  }

  void _toggleFavorite() {
    final newFav = !_isFavorited;
    setState(() {
      _isFavorited = newFav;
      _favoritesCount += newFav ? 1 : -1;
    });
    context.read<FavoritesBloc>().add(
      AddFavoriteEvent(
        postId: widget.post.id,
        userId: widget.userId,
        isFavorited: newFav,
      ),
    );
  }

  void _share() {
    setState(() => _sharesCount++);
    context.read<PostsBloc>().add(SharePostEvent(postId: widget.post.id));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: _likesCount.toString(),
            onTap: _toggleLike,
          ),
          _actionButton(
            icon: Icons.comment,
            label: widget.post.commentsCount.toString(),
            onTap: () => context.push('/comments/${widget.post.id}'),
          ),
          _actionButton(
            icon: Icons.share,
            label: _sharesCount.toString(),
            onTap: _share,
          ),
          _actionButton(
            icon: _isFavorited ? Icons.bookmark : Icons.bookmark_border,
            label: _favoritesCount.toString(),
            onTap: _toggleFavorite,
          ),
        ],
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
