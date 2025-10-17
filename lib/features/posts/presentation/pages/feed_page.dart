import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
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
    _loadCurrentUser();
    _scrollController.addListener(_onScroll);
    // For realtime, listen to stream in BLoC (add event like SubscribeToFeed)
    context.read<PostsBloc>().add(SubscribeToFeedEvent());
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
      context.read<PostsBloc>().add(GetFeedEvent(page: _currentPage));
    } else {
      context.go(Constants.loginRoute);
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 &&
        !_isLoadingMore &&
        _userId != null) {
      _isLoadingMore = true;
      _currentPage++;
      context.read<PostsBloc>().add(GetFeedEvent(page: _currentPage));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const LoadingIndicator(); // Or redirect

    return BlocProvider<PostsBloc>(
      create: (_) => sl<PostsBloc>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Feed')),
        body: RefreshIndicator(
          onRefresh: () async {
            _posts.clear();
            _currentPage = 1;
            context.read<PostsBloc>().add(GetFeedEvent(page: _currentPage));
          },
          child: BlocConsumer<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is FeedLoaded) {
                if (_currentPage == 1) _posts.clear();
                _posts.addAll(state.posts);
                _isLoadingMore = false;
              } else if (state is PostCreated) {
                _posts.insert(
                  0,
                  state.post,
                ); // Add new post to top for realtime feel
              }
            },
            builder: (context, state) {
              if (state is PostsLoading && _posts.isEmpty) {
                return const LoadingIndicator();
              } else if (state is PostsError) {
                return CustomErrorWidget(
                  message: state.message,
                  onRetry: () => context.read<PostsBloc>().add(
                    GetFeedEvent(page: _currentPage),
                  ),
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
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
