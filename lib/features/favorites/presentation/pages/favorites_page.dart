import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
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
    _loadCurrentUser();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadCurrentUser() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (user) => setState(() => _userId = user.id),
    );
    if (_userId != null) {
      context.read<FavoritesBloc>().add(
        GetFavoritesEvent(userId: _userId!, page: _currentPage),
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 &&
        !_isLoadingMore &&
        _userId != null) {
      _isLoadingMore = true;
      _currentPage++;
      context.read<FavoritesBloc>().add(
        GetFavoritesEvent(userId: _userId!, page: _currentPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FavoritesBloc>(
      create: (_) => sl<FavoritesBloc>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: BlocBuilder<FavoritesBloc, FavoritesState>(
          builder: (context, state) {
            if (state is FavoritesLoading && _favorites.isEmpty) {
              return const LoadingIndicator();
            } else if (state is FavoritesError) {
              return Center(child: Text(state.message));
            } else if (state is FavoritesLoaded) {
              if (_currentPage == 1) _favorites.clear();
              _favorites.addAll(state.posts);
              _isLoadingMore = false;
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
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
