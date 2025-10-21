import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reels_comments_overlay.dart';

class ReelActions extends StatefulWidget {
  final PostEntity post;
  final String userId;
  const ReelActions({super.key, required this.post, required this.userId});

  @override
  State<ReelActions> createState() => _ReelActionsState();
}

class _ReelActionsState extends State<ReelActions> {
  late bool _isLiked;
  late int _likesCount;
  late bool _isFavorited;
  late int _favoritesCount;
  late int _sharesCount;
  bool _likePending = false;
  bool _favoritePending = false;
  bool? _expectedIsLiked;
  bool? _expectedIsFavorited;

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
  void didUpdateWidget(covariant ReelActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likesCount;
      _isFavorited = widget.post.isFavorited;
      _favoritesCount = widget.post.favoritesCount;
      _sharesCount = widget.post.sharesCount;
      if (_likePending && _expectedIsLiked == widget.post.isLiked) {
        _likePending = false;
      }
      if (_favoritePending && _expectedIsFavorited == widget.post.isFavorited) {
        _favoritePending = false;
      }
    }
  }

  void _toggleLike() {
    if (_likePending) return;
    _likePending = true;
    final newLiked = !_isLiked;
    _expectedIsLiked = newLiked;
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
    if (_favoritePending) return;
    _favoritePending = true;
    final newFav = !_isFavorited;
    _expectedIsFavorited = newFav;
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

  void _handleComment() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) =>
          ReelsCommentsOverlay(post: widget.post, userId: widget.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PostsBloc, PostsState>(
          listener: (context, state) {
            if (state is PostsError && _likePending) {
              setState(() {
                _isLiked = !_isLiked;
                _likesCount += _isLiked ? 1 : -1;
                _likePending = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to update like')),
              );
            }
          },
        ),
        BlocListener<FavoritesBloc, FavoritesState>(
          listener: (context, state) {
            if (state is FavoritesError && _favoritePending) {
              setState(() {
                _isFavorited = !_isFavorited;
                _favoritesCount += _isFavorited ? 1 : -1;
                _favoritePending = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to update favorite')),
              );
            }
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _actionIcon(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: _likesCount.toString(),
            onTap: _toggleLike,
          ),
          _actionIcon(
            icon: Icons.comment,
            label: widget.post.commentsCount.toString(),
            onTap: _handleComment,
          ),
          _actionIcon(
            icon: Icons.share,
            label: _sharesCount.toString(),
            onTap: _share,
          ),
          _actionIcon(
            icon: _isFavorited ? Icons.bookmark : Icons.bookmark_border,
            label: _favoritesCount.toString(),
            onTap: _toggleFavorite,
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
