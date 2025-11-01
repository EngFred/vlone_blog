import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_actions.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_media.dart';

class PostCard extends StatefulWidget {
  final PostEntity post;
  final String userId;

  const PostCard({super.key, required this.post, required this.userId});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static const double _kMediaDefaultHeight = 420.0;
  late PostEntity _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update _currentPost from widget.post if it's a *different* post
    // or if the incoming post is newer (e.g., from a refresh).
    // This check prevents stomping on optimistic updates.
    if (widget.post != oldWidget.post && widget.post.id == oldWidget.post.id) {
      // If the post objects are different but the ID is the same,
      // it's likely a refresh. We should only update if the new
      // post isn't "older" than our current optimistic state.
      // For simplicity, we'll just update if the reference changes.
      // A more complex solution might use versioning or timestamps.
      _currentPost = widget.post;
    } else if (widget.post.id != oldWidget.post.id) {
      // Different post entirely
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // --- MODIFIED: LikesBloc Listener ---
        BlocListener<LikesBloc, LikesState>(
          listenWhen: (prev, curr) {
            // We ONLY care about errors for reverting,
            // or realtime updates (delta == 0) for syncing.
            if (curr is LikeError &&
                curr.postId == _currentPost.id &&
                curr.shouldRevert) {
              return true;
            }
            if (curr is LikeUpdated &&
                curr.postId == _currentPost.id &&
                curr.delta == 0 && // delta 0 implies a realtime sync
                curr.isLiked != _currentPost.isLiked) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is LikeUpdated) {
              // This is a REALTIME SYNC (e.g., from Supabase)
              AppLogger.info(
                'PostCard received REALTIME LikeUpdated for post: ${_currentPost.id}. Syncing boolean.',
              );
              // Dispatch to PostActionsBloc to update the state centrally
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost,
                  deltaLikes: 0,
                  deltaFavorites: 0,
                  isLiked: state.isLiked, // Sync the boolean
                ),
              );
            } else if (state is LikeError) {
              // This is a FAILED optimistic update. We must REVERT.
              AppLogger.info(
                'PostCard received LikeError for post: ${_currentPost.id}. Reverting count and boolean.',
              );
              // Dispatch a "revert" event to PostActionsBloc
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post:
                      _currentPost, // Pass the *current* (optimistically updated) post
                  deltaLikes: -state.delta, // Apply the *opposite* delta
                  deltaFavorites: 0,
                  isLiked:
                      state.previousState, // Revert to the previous boolean
                ),
              );
            }
          },
        ),
        // --- MODIFIED: FavoritesBloc Listener ---
        BlocListener<FavoritesBloc, FavoritesState>(
          listenWhen: (prev, curr) {
            // We ONLY care about errors for reverting,
            // or realtime updates (delta == 0) for syncing.
            if (curr is FavoriteError &&
                curr.postId == _currentPost.id &&
                curr.shouldRevert) {
              return true;
            }
            if (curr is FavoriteUpdated &&
                curr.postId == _currentPost.id &&
                curr.delta == 0 && // delta 0 implies a realtime sync
                curr.isFavorited != _currentPost.isFavorited) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is FavoriteUpdated) {
              // This is a REALTIME SYNC
              AppLogger.info(
                'PostCard received REALTIME FavoriteUpdated for post: ${_currentPost.id}. Syncing boolean.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost,
                  deltaLikes: 0,
                  deltaFavorites: 0,
                  isFavorited: state.isFavorited, // Sync the boolean
                ),
              );
            } else if (state is FavoriteError) {
              // This is a FAILED optimistic update. We must REVERT.
              AppLogger.info(
                'PostCard received FavoriteError for post: ${_currentPost.id}. Reverting count and boolean.',
              );
              // Dispatch a "revert" event to PostActionsBloc
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost,
                  deltaLikes: 0,
                  deltaFavorites: -state.delta, // Apply the *opposite* delta
                  isFavorited:
                      state.previousState, // Revert to the previous boolean
                ),
              );
            }
          },
        ),
        // --- UNCHANGED: PostActionsBloc Listener ---
        // This is now the SINGLE source of truth for updating _currentPost
        BlocListener<PostActionsBloc, PostActionsState>(
          listenWhen: (prev, curr) =>
              curr is PostOptimisticallyUpdated &&
              curr.post.id == _currentPost.id,
          listener: (context, state) {
            if (state is PostOptimisticallyUpdated) {
              AppLogger.info(
                'PostCard (PostActionsBloc) received PostOptimisticallyUpdated for post: ${state.post.id}. Updating state.',
              );
              setState(() {
                _currentPost = state.post;
              });
            }
          },
        ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: PhysicalModel(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostHeader(post: _currentPost, currentUserId: widget.userId),
                  if (_currentPost.content != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 12,
                      ),
                      child: Text(
                        _currentPost.content!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  if (_currentPost.mediaUrl != null) const SizedBox(height: 4),
                  if (_currentPost.mediaUrl != null)
                    PostMedia(post: _currentPost, height: _kMediaDefaultHeight),
                  const SizedBox(height: 12),
                  PostActions(post: _currentPost, userId: widget.userId),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
