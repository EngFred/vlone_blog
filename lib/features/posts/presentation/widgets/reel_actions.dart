import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/service/media_download_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/presentation/widgets/debounced_inkwell.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comments_overlay.dart';

class ReelActions extends StatefulWidget {
  final PostEntity post;
  final String userId;

  const ReelActions({super.key, required this.post, required this.userId});

  static const Duration _debounce = Duration(milliseconds: 500);

  @override
  State<ReelActions> createState() => _ReelActionsState();
}

class _ReelActionsState extends State<ReelActions> {
  // Local state for optimistic updates
  late PostEntity _currentPost;

  // Local state for download progress
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  @override
  void didUpdateWidget(covariant ReelActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync state if the parent widget passes a new post object
    if (widget.post != oldWidget.post && widget.post.id == oldWidget.post.id) {
      _currentPost = widget.post;
    } else if (widget.post.id != oldWidget.post.id) {
      _currentPost = widget.post;
    }
  }

  // Small helper to show snackbar via your utils (keeps UX consistent)
  void _showDownloadSnackbar(
    BuildContext context,
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    if (isError) {
      SnackbarUtils.showError(context, message, action: action);
    } else {
      SnackbarUtils.showSuccess(context, message);
    }
  }

  Future<void> _showPermissionPermanentlyDeniedSnack(
    BuildContext context,
  ) async {
    SnackbarUtils.showWarning(
      context,
      'Permission denied. Please enable storage access in app settings.',
      action: SnackBarAction(
        label: 'SETTINGS',
        textColor: Colors.white,
        onPressed: openAppSettings,
      ),
    );
  }

  void _showCommentsOverlay(BuildContext context) {
    AppLogger.info('Opening comments overlay for post: ${_currentPost.id}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        // Use _currentPost to ensure overlay has latest data
        return CommentsOverlay(post: _currentPost, userId: widget.userId);
      },
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (_isDownloading) return;

    if (_currentPost.mediaUrl == null) {
      _showDownloadSnackbar(context, 'Media URL is missing.', isError: true);
      return;
    }

    if (!sl.isRegistered<MediaDownloadService>()) {
      AppLogger.error('MediaDownloadService not registered in GetIt');
      _showDownloadSnackbar(
        context,
        'Download service not available. Try restarting the app.',
        isError: true,
      );
      return;
    }

    final MediaDownloadService downloadService = sl<MediaDownloadService>();
    final mediaType = _currentPost.mediaType ?? 'video';

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final result = await downloadService.downloadAndSaveMedia(
        _currentPost.mediaUrl!,
        mediaType,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total != -1 && total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
      });

      switch (result.status) {
        case DownloadResultStatus.success:
          _showDownloadSnackbar(context, 'Media saved to gallery!');
          break;
        case DownloadResultStatus.failure:
          AppLogger.error('Download failed: ${result.message}');
          _showDownloadSnackbar(
            context,
            result.message ?? 'Download failed. Please try again.',
            isError: true,
          );
          break;
        case DownloadResultStatus.permissionDenied:
          _showDownloadSnackbar(
            context,
            'Storage permission is required to save media.',
            isError: true,
          );
          break;
        case DownloadResultStatus.permissionPermanentlyDenied:
          AppLogger.warning('Permission permanently denied for download');
          await _showPermissionPermanentlyDeniedSnack(context);
          break;
      }
    } catch (e, st) {
      AppLogger.error('Unhandled download error', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        _showDownloadSnackbar(
          context,
          'Download failed unexpectedly. Please try again.',
          isError: true,
        );
      }
    }
  }

  Widget _buildDownloadButton(BuildContext context) {
    if (_isDownloading) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: _downloadProgress > 0 && _downloadProgress <= 1.0
              ? CircularProgressIndicator(
                  value: _downloadProgress,
                  strokeWidth: 2.5,
                  color: Colors.white,
                )
              : const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
        ),
      );
    }

    return DebouncedInkWell(
      actionKey: 'reel_download_${_currentPost.id}',
      duration: ReelActions._debounce,
      onTap: () => _handleDownload(context),
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: const Icon(Icons.file_download, color: Colors.white, size: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read all base data from the local state `_currentPost`
    final baseIsLiked = _currentPost.isLiked;
    final baseLikesCount = _currentPost.likesCount;
    final baseIsFavorited = _currentPost.isFavorited;
    final baseFavoritesCount = _currentPost.favoritesCount;
    final baseCommentsCount = _currentPost.commentsCount;

    // The MultiBlocListener is MOVED here from ReelItem
    return MultiBlocListener(
      listeners: [
        BlocListener<LikesBloc, LikesState>(
          listenWhen: (prev, curr) {
            if (curr is LikeError &&
                curr.postId == _currentPost.id &&
                curr.shouldRevert) {
              return true;
            }
            if (curr is LikeUpdated &&
                curr.postId == _currentPost.id &&
                curr.delta == 0 &&
                curr.isLiked != _currentPost.isLiked) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is LikeUpdated) {
              AppLogger.info(
                'ReelActions received REALTIME LikeUpdated for ${_currentPost.id}.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost, // Use local state
                  deltaLikes: 0,
                  deltaFavorites: 0,
                  isLiked: state.isLiked,
                ),
              );
            } else if (state is LikeError) {
              AppLogger.info(
                'ReelActions received LikeError for ${_currentPost.id} — reverting.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost, // Use local state
                  deltaLikes: -state.delta,
                  deltaFavorites: 0,
                  isLiked: state.previousState,
                ),
              );
            }
          },
        ),
        BlocListener<FavoritesBloc, FavoritesState>(
          listenWhen: (prev, curr) {
            if (curr is FavoriteError &&
                curr.postId == _currentPost.id &&
                curr.shouldRevert) {
              return true;
            }
            if (curr is FavoriteUpdated &&
                curr.postId == _currentPost.id &&
                curr.delta == 0 &&
                curr.isFavorited != _currentPost.isFavorited) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is FavoriteUpdated) {
              AppLogger.info(
                'ReelActions received REALTIME FavoriteUpdated for ${_currentPost.id}.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost, // Use local state
                  deltaLikes: 0,
                  deltaFavorites: 0,
                  isFavorited: state.isFavorited,
                ),
              );
            } else if (state is FavoriteError) {
              AppLogger.info(
                'ReelActions received FavoriteError for ${_currentPost.id} — reverting.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost, // Use local state
                  deltaLikes: 0,
                  deltaFavorites: -state.delta,
                  isFavorited: state.previousState,
                ),
              );
            }
          },
        ),
        // This listener updates the local `_currentPost` state
        BlocListener<PostActionsBloc, PostActionsState>(
          listenWhen: (prev, curr) =>
              curr is PostOptimisticallyUpdated &&
              curr.post.id == _currentPost.id,
          listener: (context, state) {
            if (state is PostOptimisticallyUpdated) {
              AppLogger.info(
                'ReelActions (PostActionsBloc) received PostOptimisticallyUpdated for post: ${state.post.id}.',
              );
              // This setState rebuilds ONLY ReelActions
              setState(() {
                _currentPost = state.post;
              });
            }
          },
        ),
      ],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // ==================== LIKE BUTTON ====================
          BlocBuilder<LikesBloc, LikesState>(
            buildWhen: (prev, curr) {
              if (curr is LikesInitial) return true;
              // Use _currentPost.id
              if (curr is LikeUpdated && curr.postId == _currentPost.id) {
                return true;
              }
              if (curr is LikeError &&
                  curr.postId == _currentPost.id &&
                  curr.shouldRevert) {
                return true;
              }
              return false;
            },
            builder: (context, state) {
              // Use local state `baseIsLiked` as the source of truth
              bool isLiked = baseIsLiked;
              int likesCount = baseLikesCount;

              if (state is LikeUpdated && state.postId == _currentPost.id) {
                isLiked = state.isLiked;
              } else if (state is LikeError &&
                  state.postId == _currentPost.id &&
                  state.shouldRevert) {
                isLiked = state.previousState;
              }

              return DebouncedInkWell(
                actionKey: 'reel_like_${_currentPost.id}',
                duration: ReelActions._debounce,
                onTap: () {
                  context.read<LikesBloc>().add(
                    LikePostEvent(
                      postId: _currentPost.id, // Use local state
                      userId: widget.userId,
                      isLiked: !isLiked,
                      previousState: isLiked,
                    ),
                  );

                  final int delta = (!isLiked) ? 1 : -1;
                  context.read<PostActionsBloc>().add(
                    OptimisticPostUpdate(
                      post: _currentPost, // Use local state
                      deltaLikes: delta,
                      deltaFavorites: 0,
                      isLiked: !isLiked,
                      isFavorited: null,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Column(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                      size: 32,
                    ),
                    Text(
                      likesCount.toString(), // Use local state
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ==================== COMMENT BUTTON ====================
          DebouncedInkWell(
            actionKey: 'reel_comment_${_currentPost.id}',
            duration: ReelActions._debounce,
            onTap: () => _showCommentsOverlay(context),
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 32,
                ),
                if (baseCommentsCount > 0) // Use local state
                  Text(
                    baseCommentsCount.toString(), // Use local state
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ==================== FAVORITE BUTTON ====================
          BlocBuilder<FavoritesBloc, FavoritesState>(
            buildWhen: (prev, curr) {
              if (curr is FavoritesInitial) return true;
              if (curr is FavoriteUpdated && curr.postId == _currentPost.id) {
                return true;
              }
              if (curr is FavoriteError &&
                  curr.postId == _currentPost.id &&
                  curr.shouldRevert) {
                return true;
              }
              return false;
            },
            builder: (context, state) {
              // Use local state `baseIsFavorited` as the source of truth
              bool isFavorited = baseIsFavorited;
              int favoritesCount = baseFavoritesCount; // Use local state

              if (state is FavoriteUpdated && state.postId == _currentPost.id) {
                isFavorited = state.isFavorited;
              } else if (state is FavoriteError &&
                  state.postId == _currentPost.id &&
                  state.shouldRevert) {
                isFavorited = state.previousState;
              }

              return DebouncedInkWell(
                actionKey: 'reel_fav_${_currentPost.id}',
                duration: ReelActions._debounce,
                onTap: () {
                  context.read<FavoritesBloc>().add(
                    FavoritePostEvent(
                      postId: _currentPost.id, // Use local state
                      userId: widget.userId,
                      isFavorited: !isFavorited,
                      previousState: isFavorited,
                    ),
                  );

                  final int deltaFav = (!isFavorited) ? 1 : -1;
                  context.read<PostActionsBloc>().add(
                    OptimisticPostUpdate(
                      post: _currentPost, // Use local state
                      deltaLikes: 0,
                      deltaFavorites: deltaFav,
                      isLiked: null,
                      isFavorited: !isFavorited,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Column(
                  children: [
                    Icon(
                      isFavorited ? Icons.bookmark : Icons.bookmark_border,
                      color: isFavorited ? Colors.amber : Colors.white,
                      size: 32,
                    ),
                    Text(
                      favoritesCount.toString(), // Use local state
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildDownloadButton(context),
        ],
      ),
    );
  }
}
