import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
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
    if (_controller != null && _controller != controller) {
      _controller?.pause();
      _onPauseCallback?.call();
    }
    _controller = controller;
    _onPauseCallback = onPauseCallback;
    _controller?.play();
  }

  static void pause() {
    _controller?.pause();
    _onPauseCallback?.call();
    _controller = null;
    _onPauseCallback = null;
  }

  static bool isPlaying(VideoPlayerController controller) {
    return _controller == controller && _controller!.value.isPlaying;
  }
}

/// Singleton manager for caching and reusing VideoPlayerController instances
class VideoControllerManager {
  VideoControllerManager._();
  static final VideoControllerManager _instance = VideoControllerManager._();
  factory VideoControllerManager() => _instance;

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, int> _refCounts = {};

  Future<VideoPlayerController> getController(String postId, String url) async {
    if (_controllers.containsKey(postId)) {
      _refCounts[postId] = (_refCounts[postId] ?? 0) + 1;
      return _controllers[postId]!;
    }

    // Download/cache video file using DefaultCacheManager
    final File file = await DefaultCacheManager().getSingleFile(url);

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    controller.setLooping(true);

    _controllers[postId] = controller;
    _refCounts[postId] = 1;
    return controller;
  }

  void releaseController(String postId) {
    if (!_controllers.containsKey(postId)) return;
    _refCounts[postId] = (_refCounts[postId] ?? 1) - 1;
    if ((_refCounts[postId] ?? 0) <= 0) {
      try {
        _controllers[postId]?.dispose();
      } catch (_) {}
      _controllers.remove(postId);
      _refCounts.remove(postId);
    }
  }

  void disposeAll() {
    for (final c in _controllers.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    _refCounts.clear();
  }
}

class PostCard extends StatefulWidget {
  final PostEntity post;
  final String userId;
  const PostCard({super.key, required this.post, required this.userId});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  late bool _isLiked;
  late int _likesCount;
  late bool _isFavorited;
  late int _favoritesCount;
  late int _sharesCount;

  final VideoControllerManager _videoManager = VideoControllerManager();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _syncFromPost();
  }

  void _syncFromPost() {
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _isFavorited = widget.post.isFavorited;
    _favoritesCount = widget.post.favoritesCount;
    _sharesCount = widget.post.sharesCount;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.likesCount != widget.post.likesCount ||
        oldWidget.post.isFavorited != widget.post.isFavorited ||
        oldWidget.post.favoritesCount != widget.post.favoritesCount ||
        oldWidget.post.sharesCount != widget.post.sharesCount) {
      _syncFromPost();
    }
  }

  Future<void> _ensureControllerInitialized() async {
    if (_videoController != null && _initialized) return;
    try {
      final controller = await _videoManager.getController(
        widget.post.id,
        widget.post.mediaUrl!,
      );
      if (!mounted) {
        // If widget unmounted before controller returns, release it
        _videoManager.releaseController(widget.post.id);
        return;
      }
      setState(() {
        _videoController = controller;
        _initialized = true;
      });
    } catch (e) {
      // ignore - show error widget instead
    }
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
        if (mounted) setState(() {});
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                if (mounted) {
                  setState(() {
                    _isLiked = !_isLiked;
                    _likesCount += _isLiked ? 1 : -1;
                    _sharesCount--;
                  });
                }
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoritesError) {
                if (mounted) {
                  setState(() {
                    _isFavorited = !_isFavorited;
                    _favoritesCount += _isFavorited ? 1 : -1;
                  });
                }
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
              if (widget.post.content != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(widget.post.content!),
                ),
              ],
              if (widget.post.mediaUrl != null) ...[
                const SizedBox(height: 8),
                if (widget.post.mediaType == 'image')
                  CachedNetworkImage(
                    imageUrl: widget.post.mediaUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 300,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  )
                else if (widget.post.mediaType == 'video')
                  Builder(
                    builder: (context) {
                      // Use VisibilityDetector to initialize controller when needed
                      return VisibilityDetector(
                        key: Key(widget.post.id),
                        onVisibilityChanged: (visibilityInfo) {
                          final visiblePct =
                              visibilityInfo.visibleFraction * 100;
                          if (visiblePct > 40 && !_initialized) {
                            // initialize but don't autoplay unless user taps or manager plays
                            _ensureControllerInitialized();
                          }
                          // Pause playback when mostly offscreen
                          if (visiblePct < 20 &&
                              _videoController != null &&
                              _VideoPlaybackManager.isPlaying(
                                _videoController!,
                              )) {
                            _VideoPlaybackManager.pause();
                          }
                        },
                        child: GestureDetector(
                          onTap: _initialized ? _togglePlayPause : null,
                          child: AspectRatio(
                            aspectRatio:
                                _initialized && _videoController != null
                                ? _videoController!.value.aspectRatio
                                : 16 / 9,
                            child: _initialized && _videoController != null
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      VideoPlayer(_videoController!),
                                      if (!_VideoPlaybackManager.isPlaying(
                                        _videoController!,
                                      ))
                                        const Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.white,
                                          size: 64.0,
                                        ),
                                    ],
                                  )
                                : // If we don't have a cached thumbnail, show a placeholder—if your PostEntity has a thumbnailUrl, use CachedNetworkImage there
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: 300,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceVariant,
                                        child:
                                            (widget.post.thumbnailUrl != null)
                                            ? CachedNetworkImage(
                                                imageUrl:
                                                    widget.post.thumbnailUrl!,
                                                fit: BoxFit.cover,
                                              )
                                            : const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                      ),
                                      const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                        size: 64.0,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  )
                else
                  const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
              const SizedBox(height: 8),
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
                          userId: widget.userId,
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
                    onPressed: () {
                      setState(() => _sharesCount++);
                      context.read<PostsBloc>().add(
                        SharePostEvent(postId: widget.post.id),
                      );
                    },
                  ),
                  Text(_sharesCount.toString()),
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
                          userId: widget.userId,
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
    // Release ref-counted controller; manager will dispose when refCount reaches 0.
    if (widget.post.mediaType == 'video') {
      _videoManager.releaseController(widget.post.id);
      if (_videoController != null &&
          _VideoPlaybackManager.isPlaying(_videoController!)) {
        _VideoPlaybackManager.pause();
      }
    }
    super.dispose();
  }
}
