import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';

class PostCard extends StatefulWidget {
  final PostEntity post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  bool _isLiked = false;
  bool _isFavorited = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    if (widget.post.mediaType == 'video' && widget.post.mediaUrl != null) {
      _videoController = VideoPlayerController.network(widget.post.mediaUrl!)
        ..initialize().then((_) => setState(() {}));
    }
    // Fetch if liked/favorited: For quality, add queries, but assume false initially for simplicity
    // To improve, can add IsLikedUseCase or query in bloc
  }

  Future<void> _loadCurrentUser() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold(
      (failure) => null, // Handle error
      (user) => setState(() => _userId = user.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const SizedBox.shrink(); // Or loading

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<PostsBloc>()),
        BlocProvider.value(value: context.read<FavoritesBloc>()),
      ],
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const CircleAvatar(), // Fetch user profile image
              title: const Text('Username'), // Fetch from profile
              subtitle: Text(widget.post.formattedCreatedAt),
              onTap: () => context.push('/profile/${widget.post.userId}'),
            ),
            if (widget.post.content != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(widget.post.content!),
              ),
            if (widget.post.mediaUrl != null)
              if (widget.post.mediaType == 'image')
                CachedNetworkImage(
                  imageUrl: widget.post.mediaUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 300,
                )
              else if (widget.post.mediaType == 'video' &&
                  _videoController != null &&
                  _videoController!.value.isInitialized)
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                  onPressed: () {
                    setState(() => _isLiked = !_isLiked);
                    context.read<PostsBloc>().add(
                      LikePostEvent(
                        postId: widget.post.id,
                        userId: _userId!,
                        isLiked: _isLiked,
                      ),
                    );
                  },
                ),
                Text(widget.post.likesCount.toString()),
                IconButton(
                  icon: const Icon(Icons.comment),
                  onPressed: () => context.push('/comments/${widget.post.id}'),
                ),
                Text(widget.post.commentsCount.toString()),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => context.read<PostsBloc>().add(
                    SharePostEvent(postId: widget.post.id),
                  ),
                ),
                Text(widget.post.sharesCount.toString()),
                IconButton(
                  icon: Icon(
                    _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  onPressed: () {
                    setState(() => _isFavorited = !_isFavorited);
                    context.read<FavoritesBloc>().add(
                      AddFavoriteEvent(
                        postId: widget.post.id,
                        userId: _userId!,
                        isFavorited: _isFavorited,
                      ),
                    );
                  },
                ),
                Text(widget.post.favoritesCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
}
