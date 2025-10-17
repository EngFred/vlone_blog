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
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String? _userId;
  final _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  final List<PostEntity> _favorites = [];

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FavoritesPage');
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AppLogger.info('Loading current user for FavoritesPage');
    try {
      final result = await sl<GetCurrentUserUseCase>()(NoParams());
      result.fold(
        (failure) {
          AppLogger.error('Failed to load current user: ${failure.message}');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
          context.go(Constants.loginRoute);
        },
        (user) {
          AppLogger.info('Current user loaded: ${user.id}');
          setState(() => _userId = user.id);
          if (_userId != null) {
            AppLogger.info(
              'Fetching initial favorites for user: ${_userId}, page: $_currentPage',
            );
            context.read<FavoritesBloc>().add(
              GetFavoritesEvent(userId: _userId!, page: _currentPage),
            );
          }
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error loading user: $e', error: e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading user: $e')));
      context.go(Constants.loginRoute);
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 &&
        !_isLoadingMore &&
        _userId != null) {
      _isLoadingMore = true;
      _currentPage++;
      AppLogger.info(
        'Fetching more favorites for user: $_userId, page: $_currentPage',
      );
      context.read<FavoritesBloc>().add(
        GetFavoritesEvent(userId: _userId!, page: _currentPage),
      );
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
            if (_currentPage == 1) _favorites.clear();
            _favorites.addAll(state.posts);
            _isLoadingMore = false;
          } else if (state is FavoritesError) {
            AppLogger.error('Favorites load failed: ${state.message}');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is FavoriteAdded) {
            AppLogger.info(
              'Favorite added for post: ${state.postId} by user: $_userId',
            );
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
                AppLogger.info(
                  'Retrying favorites load for user: $_userId, page: $_currentPage',
                );
                context.read<FavoritesBloc>().add(
                  GetFavoritesEvent(userId: _userId!, page: _currentPage),
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
          return ListView.builder(
            controller: _scrollController,
            itemCount: _favorites.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _favorites.length) {
                return PostCard(post: _favorites[index]);
              } else {
                return const LoadingIndicator();
              }
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing FavoritesPage, cleaning up scroll controller');
    _scrollController.dispose();
    super.dispose();
  }
}
