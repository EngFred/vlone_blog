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
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _scrollController = ScrollController();
  int _currentPage = 1;
  final List<PostEntity> _posts = [];
  bool _isLoadingMore = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FeedPage');
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AppLogger.info('Loading current user for FeedPage');
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
              'Fetching initial feed for user: ${_userId}, page: $_currentPage',
            );
            context.read<PostsBloc>().add(GetFeedEvent(page: _currentPage));
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
        'Fetching more posts for user: ${_userId}, page: $_currentPage',
      );
      context.read<PostsBloc>().add(GetFeedEvent(page: _currentPage));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const LoadingIndicator();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: RefreshIndicator(
        onRefresh: () async {
          AppLogger.info('Refreshing feed for user: $_userId');
          _posts.clear();
          _currentPage = 1;
          context.read<PostsBloc>().add(GetFeedEvent(page: _currentPage));
        },
        child: BlocConsumer<PostsBloc, PostsState>(
          listener: (context, state) {
            if (state is FeedLoaded) {
              AppLogger.info(
                'Feed loaded with ${state.posts.length} posts for user: $_userId',
              );
              if (_currentPage == 1) _posts.clear();
              _posts.addAll(state.posts);
              _isLoadingMore = false;
            } else if (state is PostCreated) {
              AppLogger.info('New post created: ${state.post.id}');
              _posts.insert(0, state.post);
            }
          },
          builder: (context, state) {
            if (state is PostsLoading && _posts.isEmpty) {
              return const LoadingIndicator();
            } else if (state is PostsError) {
              return EmptyStateWidget(
                message: state.message,
                icon: Icons.error_outline,
                onRetry: () {
                  AppLogger.info(
                    'Retrying feed fetch for user: $_userId, page: $_currentPage',
                  );
                  context.read<PostsBloc>().add(
                    GetFeedEvent(page: _currentPage),
                  );
                },
                actionText: 'Retry',
              );
            } else if (_posts.isEmpty) {
              return const EmptyStateWidget(
                message: 'No posts yet. Create one to get started!',
                icon: Icons.post_add,
              );
            }
            return ListView.builder(
              controller: _scrollController,
              itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _posts.length) {
                  return PostCard(post: _posts[index]);
                } else {
                  return const LoadingIndicator();
                }
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-post'),
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing FeedPage, cleaning up scroll controller');
    _scrollController.dispose();
    super.dispose();
  }
}
