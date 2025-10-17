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
  late bool _isLiked;
  late int _likesCount;
  late bool _isFavorited;
  late int _favoritesCount;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _isFavorited = widget.post.isFavorited;
    _favoritesCount = widget.post.favoritesCount;
    _loadCurrentUser();
    if (widget.post.mediaType == 'video' && widget.post.mediaUrl != null) {
      _videoController = VideoPlayerController.network(widget.post.mediaUrl!)
        ..initialize().then((_) => setState(() {}));
    }
  }

  Future<void> _loadCurrentUser() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold(
      (failure) => null, // Handle error appropriately in production
      (user) => setState(() => _userId = user.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const SizedBox.shrink();

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<PostsBloc>()),
        BlocProvider.value(value: context.read<FavoritesBloc>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is PostsError) {
                // Basic reversion on error (assumes last action was for this post; refine if needed)
                setState(() {
                  _isLiked = !_isLiked;
                  _likesCount += _isLiked ? -1 : 1;
                });
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoritesError) {
                // Basic reversion
                setState(() {
                  _isFavorited = !_isFavorited;
                  _favoritesCount += _isFavorited ? -1 : 1;
                });
              }
            },
          ),
        ],
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: widget.post.avatarUrl != null
                      ? NetworkImage(widget.post.avatarUrl!)
                      : null,
                  child: widget.post.avatarUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(widget.post.username ?? 'Unknown'),
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
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                    ),
                    onPressed: () {
                      final newLiked = !_isLiked;
                      setState(() {
                        _isLiked = newLiked;
                        _likesCount += newLiked ? 1 : -1;
                      });
                      context.read<PostsBloc>().add(
                        LikePostEvent(
                          postId: widget.post.id,
                          userId: _userId!,
                          isLiked: newLiked,
                        ),
                      );
                    },
                  ),
                  Text(_likesCount.toString()),
                  IconButton(
                    icon: const Icon(Icons.comment),
                    onPressed: () =>
                        context.push('/comments/${widget.post.id}'),
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
                      final newFavorited = !_isFavorited;
                      setState(() {
                        _isFavorited = newFavorited;
                        _favoritesCount += newFavorited ? 1 : -1;
                      });
                      context.read<FavoritesBloc>().add(
                        AddFavoriteEvent(
                          postId: widget.post.id,
                          userId: _userId!,
                          isFavorited: newFavorited,
                        ),
                      );
                    },
                  ),
                  Text(_favoritesCount.toString()),
                ],
              ),
            ],
          ),
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
