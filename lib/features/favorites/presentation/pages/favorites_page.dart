import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_interactions_usecase.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String? _userId;
  final List<PostEntity> _favorites = [];

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FavoritesPage');
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AppLogger.info('Loading current user for FavoritesPage');
    try {
      final result = await sl<GetCurrentUserUseCase>()(NoParams());
      result.fold(
        (failure) {
          AppLogger.error('Failed to load current user: ${failure.message}');
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
            context.go(Constants.loginRoute);
          }
        },
        (user) {
          AppLogger.info('Current user loaded: ${user.id}');
          if (mounted) {
            setState(() => _userId = user.id);
          }
          if (_userId != null) {
            AppLogger.info('Fetching initial favorites for user: $_userId');
            context.read<FavoritesBloc>().add(
              GetFavoritesEvent(userId: _userId!),
            );
          }
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error loading user: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading user: $e')));
        context.go(Constants.loginRoute);
      }
    }
  }

  Future<void> _fetchInteractionStates() async {
    if (_userId == null || _favorites.isEmpty) return;
    final postIds = _favorites.map((p) => p.id).toList();
    try {
      final result = await sl<GetPostInteractionsUseCase>()(
        GetPostInteractionsParams(userId: _userId!, postIds: postIds),
      );
      result.fold(
        (failure) {
          AppLogger.error('Failed to fetch interactions: ${failure.message}');
        },
        (interactionStates) {
          if (!mounted) return;
          setState(() {
            for (int i = 0; i < _favorites.length; i++) {
              final post = _favorites[i];
              _favorites[i] = post.copyWith(
                isLiked: interactionStates.isLiked(post.id),
                isFavorited: interactionStates.isFavorited(
                  post.id,
                ), // Confirm despite pre-set
              );
            }
          });
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error fetching interactions: $e', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const LoadingIndicator();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: BlocConsumer<FavoritesBloc, FavoritesState>(
        listener: (context, state) {
          if (state is FavoritesLoaded) {
            AppLogger.info(
              'Favorites loaded with ${state.posts.length} posts for user: $_userId',
            );
            if (mounted) {
              setState(() {
                _favorites.clear();
                _favorites.addAll(
                  state.posts.map((p) => p.copyWith(isFavorited: true)),
                ); // Pre-set as favorites
              });
              _fetchInteractionStates();
            }
          } else if (state is FavoritesError) {
            AppLogger.error('Favorites load failed: ${state.message}');
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
          } else if (state is FavoriteAdded) {
            AppLogger.info(
              'Favorite toggled for post: ${state.postId} (favorited: ${state.isFavorited}) by user: $_userId',
            );
            if (!state.isFavorited && mounted) {
              // Remove if unfavorited (e.g., from PostActions on this page or elsewhere)
              setState(() {
                _favorites.removeWhere((p) => p.id == state.postId);
              });
            }
            // For add: Optionally refresh list if needed, but skip for now
          }
        },
        builder: (context, state) {
          if (state is FavoritesLoading && _favorites.isEmpty) {
            return const LoadingIndicator();
          } else if (state is FavoritesError) {
            return EmptyStateWidget(
              message: state.message,
              icon: Icons.error_outline,
              onRetry: () {
                AppLogger.info('Retrying favorites load for user: $_userId');
                context.read<FavoritesBloc>().add(
                  GetFavoritesEvent(userId: _userId!),
                );
              },
              actionText: 'Retry',
            );
          } else if (_favorites.isEmpty) {
            return const EmptyStateWidget(
              message: 'No favorite posts yet.',
              icon: Icons.favorite_border,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              AppLogger.info('Refreshing favorites for user: $_userId');
              if (mounted) {
                setState(() => _favorites.clear());
              }
              context.read<FavoritesBloc>().add(
                GetFavoritesEvent(userId: _userId!),
              );
            },
            child: ListView.builder(
              cacheExtent: 1500.0, // For smoothness with media
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final post = _favorites[index];
                return PostCard(
                  key: ValueKey(
                    post.id,
                  ), // Preserve widget state during updates
                  post: post,
                  userId: _userId!,
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing FavoritesPage');
    super.dispose();
  }
}
