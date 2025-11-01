import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';
import 'package:vlone_blog_app/features/users/presentation/widgets/user_list_item.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String? _currentUserId;
  final Set<String> _loadingUserIds = <String>{};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && mounted) {
        setState(() => _currentUserId = authState.user.id);
        AppLogger.info('UsersPage: Set currentUserId=$_currentUserId');
      }
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          context.read<UsersBloc>().state is UsersLoaded &&
          (context.read<UsersBloc>().state as UsersLoaded).hasMore) {
        context.read<UsersBloc>().add(const LoadMoreUsersEvent());
      }
    });
  }

  void _handleFollowUpdate(String followedUserId, bool nowFollowing) {
    if (!mounted) return;
    context.read<UsersBloc>().add(
      UpdateUserFollowStatusEvent(followedUserId, nowFollowing),
    );
    _loadingUserIds.remove(followedUserId);
  }

  void _retryFetch() {
    if (_currentUserId != null) {
      AppLogger.info('Retrying fetch users for $_currentUserId');
      context.read<UsersBloc>().add(RefreshUsersEvent(_currentUserId!));
    } else {
      AppLogger.warning(
        'Retry attempted but currentUserId is null — ask AuthBloc to provide user or sign-in.',
      );
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _currentUserId = authState.user.id;
        context.read<UsersBloc>().add(GetPaginatedUsersEvent(_currentUserId!));
      } else {
        SnackbarUtils.showError(
          context,
          'You must be signed in to load users.',
        );
      }
    }
  }

  void _onRefresh() {
    if (_currentUserId != null) {
      context.read<UsersBloc>().add(RefreshUsersEvent(_currentUserId!));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildLoadingMoreFooter(bool hasMore, String? loadMoreError) {
    if (!hasMore) return const SizedBox.shrink();

    if (loadMoreError != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              'Failed to load more users',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () =>
                  context.read<UsersBloc>().add(const LoadMoreUsersEvent()),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          children: [
            LoadingIndicator(size: 20),
            SizedBox(height: 8),
            Text(
              'Loading more users...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Discover People',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 4,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _onRefresh(),
        child: MultiBlocListener(
          listeners: [
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthAuthenticated) {
                  AppLogger.info(
                    'AuthBloc -> Authenticated in UsersPage, userId=${state.user.id}',
                  );
                  _currentUserId = state.user.id;
                  context.read<UsersBloc>().add(
                    GetPaginatedUsersEvent(_currentUserId!),
                  );
                }
              },
            ),
            BlocListener<FollowersBloc, FollowersState>(
              listener: (context, state) {
                if (state is UserFollowed) {
                  AppLogger.info(
                    'FollowersBloc -> Follow update: ${state.followedUserId} nowFollowing=${state.isFollowing}',
                  );
                  _handleFollowUpdate(state.followedUserId, state.isFollowing);
                } else if (state is FollowersError &&
                    _loadingUserIds.isNotEmpty) {
                  AppLogger.error('FollowersBloc error: ${state.message}');
                  _loadingUserIds.clear();
                  SnackbarUtils.showError(
                    context,
                    'Failed to update follow: ${state.message}',
                  );
                }
              },
            ),
          ],
          child: BlocBuilder<UsersBloc, UsersState>(
            builder: (context, state) {
              if (state is UsersLoading || state is UsersInitial) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LoadingIndicator(size: 32),
                      SizedBox(height: 16),
                      Text(
                        'Loading users...',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              if (state is UsersError) {
                return CustomErrorWidget(
                  message: 'Failed to load users:\n${state.message}',
                  onRetry: _retryFetch,
                );
              }

              if (state is UsersLoadMoreError) {
                return _buildListView(state.currentUsers, true, state.message);
              }

              if (state is UsersLoadingMore) {
                return _buildListView(state.currentUsers, true, null);
              }

              if (state is UsersLoaded) {
                if (state.users.isEmpty) {
                  return EmptyStateWidget(
                    message: 'No users found',
                    icon: Icons.people_outline,
                    actionText: 'Refresh',
                    onRetry: _retryFetch,
                  );
                }
                return _buildListView(state.users, state.hasMore, null);
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListView(
    List<UserListEntity> users,
    bool hasMore,
    String? loadMoreError,
  ) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final user = users[index];
            return UserListItem(
              key: ValueKey(user.id),
              user: user,
              currentUserId: _currentUserId ?? '',
              isLoading: _loadingUserIds.contains(user.id),
              onFollowToggle: (followedId, isFollowing) {
                if (_currentUserId == null) {
                  SnackbarUtils.showError(
                    context,
                    'You must be signed in to follow users.',
                  );
                  return;
                }
                _loadingUserIds.add(followedId);
                context.read<FollowersBloc>().add(
                  FollowUserEvent(
                    followerId: _currentUserId!,
                    followingId: followedId,
                    isFollowing: isFollowing,
                  ),
                );
                _handleFollowUpdate(followedId, isFollowing);
              },
            );
          }, childCount: users.length),
        ),
        SliverToBoxAdapter(
          child: _buildLoadingMoreFooter(hasMore, loadMoreError),
        ),
      ],
    );
  }
}
