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
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

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
    AppLogger.info('Opening comments overlay for post: ${widget.post.id}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return CommentsOverlay(post: widget.post, userId: widget.userId);
      },
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (_isDownloading) return;

    if (widget.post.mediaUrl == null) {
      _showDownloadSnackbar(context, 'Media URL is missing.', isError: true);
      return;
    }

    // Defensive: ensure MediaDownloadService is registered
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

    // Determine media type (assume reels are video)
    final mediaType = widget.post.mediaType ?? 'video';

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    // show immediate feedback
    // SnackbarUtils.showInfo(context, 'Starting download...');

    try {
      final result = await downloadService.downloadAndSaveMedia(
        widget.post.mediaUrl!,
        mediaType,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          // if total == -1, we can't compute progress -> show indeterminate indicator
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
    // Match tap area and sizing to the FullMediaPage implementation
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
                  // do not hardcode color here if your theme handles it;
                  // using white to match existing UI pattern in the app
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
      actionKey: 'reel_download_${widget.post.id}',
      duration: ReelActions._debounce,
      onTap: () => _handleDownload(context),
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: const Icon(Icons.file_download, color: Colors.white, size: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseIsLiked = widget.post.isLiked;
    final baseLikesCount = widget.post.likesCount;
    final baseIsFavorited = widget.post.isFavorited;
    final baseCommentsCount = widget.post.commentsCount;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // ==================== LIKE BUTTON ====================
        BlocBuilder<LikesBloc, LikesState>(
          buildWhen: (prev, curr) {
            if (curr is LikesInitial) return true;
            if (curr is LikeUpdated && curr.postId == widget.post.id) {
              return true;
            }
            if (curr is LikeError &&
                curr.postId == widget.post.id &&
                curr.shouldRevert) {
              return true;
            }
            return false;
          },
          builder: (context, state) {
            bool isLiked = baseIsLiked;
            int likesCount = baseLikesCount;

            if (state is LikeUpdated && state.postId == widget.post.id) {
              isLiked = state.isLiked;
            } else if (state is LikeError &&
                state.postId == widget.post.id &&
                state.shouldRevert) {
              isLiked = state.previousState;
            }

            return DebouncedInkWell(
              actionKey: 'reel_like_${widget.post.id}',
              duration: ReelActions._debounce,
              onTap: () {
                context.read<LikesBloc>().add(
                  LikePostEvent(
                    postId: widget.post.id,
                    userId: widget.userId,
                    isLiked: !isLiked,
                    previousState: isLiked,
                  ),
                );

                final int delta = (!isLiked) ? 1 : -1;
                context.read<PostActionsBloc>().add(
                  OptimisticPostUpdate(
                    post: widget.post,
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
                    likesCount.toString(),
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
          actionKey: 'reel_comment_${widget.post.id}',
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
              if (baseCommentsCount > 0)
                Text(
                  baseCommentsCount.toString(),
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
            if (curr is FavoriteUpdated && curr.postId == widget.post.id) {
              return true;
            }
            if (curr is FavoriteError &&
                curr.postId == widget.post.id &&
                curr.shouldRevert) {
              return true;
            }
            return false;
          },
          builder: (context, state) {
            bool isFavorited = baseIsFavorited;
            int favoritesCount = widget.post.favoritesCount;

            if (state is FavoriteUpdated && state.postId == widget.post.id) {
              isFavorited = state.isFavorited;
            } else if (state is FavoriteError &&
                state.postId == widget.post.id &&
                state.shouldRevert) {
              isFavorited = state.previousState;
            }

            return DebouncedInkWell(
              actionKey: 'reel_fav_${widget.post.id}',
              duration: ReelActions._debounce,
              onTap: () {
                context.read<FavoritesBloc>().add(
                  FavoritePostEvent(
                    postId: widget.post.id,
                    userId: widget.userId,
                    isFavorited: !isFavorited,
                    previousState: isFavorited,
                  ),
                );

                final int deltaFav = (!isFavorited) ? 1 : -1;
                context.read<PostActionsBloc>().add(
                  OptimisticPostUpdate(
                    post: widget.post,
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
                    favoritesCount.toString(),
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
        // This now shows progress while downloading and handles snackbars.
        _buildDownloadButton(context),
      ],
    );
  }
}
