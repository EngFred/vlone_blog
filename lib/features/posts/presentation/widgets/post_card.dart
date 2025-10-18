import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';

/// Manages the currently playing video to ensure only one plays at a time.
class _VideoPlaybackManager {
  static VideoPlayerController? _controller;
  static VoidCallback? _onPauseCallback;
  static void play(
    VideoPlayerController controller,
    VoidCallback onPauseCallback,
  ) {
    // If another video is playing, pause it and notify its card to update UI.
    if (_controller != null && _controller != controller) {
      _controller?.pause();
      _onPauseCallback?.call();
    }
    _controller = controller;
    _onPauseCallback = onPauseCallback;
    _controller?.play();
  }

  /// Pauses the currently playing video.
  static void pause() {
    _controller?.pause();
    _onPauseCallback?.call();
    // Clear the references
    _controller = null;
    _onPauseCallback = null;
  }

  /// Checks if the given controller is the one currently playing.
  static bool isPlaying(VideoPlayerController controller) {
    return _controller == controller;
  }
}

class PostCard extends StatefulWidget {
  final PostEntity post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  late bool _isLiked;
  late int _likesCount;
  late bool _isFavorited;
  late int _favoritesCount;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _syncFromPost();
    _loadCurrentUser();
  }

  void _syncFromPost() {
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _isFavorited = widget.post.isFavorited;
    _favoritesCount = widget.post.favoritesCount;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.likesCount != widget.post.likesCount ||
        oldWidget.post.isFavorited != widget.post.isFavorited ||
        oldWidget.post.favoritesCount != widget.post.favoritesCount) {
      _syncFromPost();
    }
  }

  Future<void> _loadCurrentUser() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold((failure) => null, (user) => setState(() => _userId = user.id));
  }

  void _togglePlayPause() {
    if (_videoController == null || !_initialized) return;
    final isCurrentlyPlaying = _VideoPlaybackManager.isPlaying(
      _videoController!,
    );
    if (isCurrentlyPlaying) {
      _VideoPlaybackManager.pause();
    } else {
      _VideoPlaybackManager.play(_videoController!, () {
        if (mounted) {
          setState(() {}); // Rebuild to show the play icon.
        }
      });
    }
    setState(() {}); // Rebuild current card to show pause/play icon.
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
                // If there's an error liking/unliking, revert the UI state
                setState(() {
                  _isLiked = !_isLiked;
                  _likesCount += _isLiked ? 1 : -1;
                });
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoritesError) {
                // If there's an error favoriting/unfavoriting, revert the UI state
                setState(() {
                  _isFavorited = !_isFavorited;
                  _favoritesCount += _isFavorited ? 1 : -1;
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                else if (widget.post.mediaType == 'video')
                  Builder(
                    builder: (context) {
                      _videoController ??= VideoPlayerController.networkUrl(
                        Uri.parse(widget.post.mediaUrl!),
                      );
                      _videoController!.addListener(() {
                        // When video finishes, ensure UI updates to show play icon again.
                        if (!_videoController!.value.isPlaying &&
                            _videoController!.value.position >=
                                _videoController!.value.duration) {
                          if (mounted) {
                            setState(() {});
                          }
                          _videoController!.seekTo(Duration.zero);
                        }
                      });
                      return VisibilityDetector(
                        key: Key(widget.post.id),
                        onVisibilityChanged: (visibilityInfo) {
                          final visiblePercentage =
                              visibilityInfo.visibleFraction * 100;
                          if (visiblePercentage > 0 && !_initialized) {
                            _videoController!.initialize().then((_) {
                              if (mounted) {
                                setState(() {
                                  _initialized = true;
                                });
                              }
                            });
                          }
                          if (visiblePercentage < 70 &&
                              _VideoPlaybackManager.isPlaying(
                                _videoController!,
                              )) {
                            _VideoPlaybackManager.pause();
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTap: _initialized ? _togglePlayPause : null,
                              child: AspectRatio(
                                aspectRatio: _initialized
                                    ? _videoController!.value.aspectRatio
                                    : 16 / 9,
                                child: _initialized
                                    ? VideoPlayer(_videoController!)
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                              ),
                            ),
                            if (_initialized &&
                                !_VideoPlaybackManager.isPlaying(
                                  _videoController!,
                                ))
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 64.0,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
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
    if (_videoController != null &&
        _VideoPlaybackManager.isPlaying(_videoController!)) {
      _VideoPlaybackManager.pause();
    }
    _videoController?.dispose();
    super.dispose();
  }
}
