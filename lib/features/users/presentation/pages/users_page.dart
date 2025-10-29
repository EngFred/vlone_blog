import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
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
        // Removed: context.read<UsersBloc>().add(GetPaginatedUsersEvent(_currentUserId!)); - handled by MainPage
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
    // Dispatch event for optimistic update via Bloc
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _onRefresh(),
        child: MultiBlocListener(
          listeners: [
            // Listen to Auth state so if the user signs in after this page was created we fetch users.
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthAuthenticated) {
                  AppLogger.info(
                    'AuthBloc -> Authenticated in UsersPage, userId=${state.user.id}',
                  );
                  _currentUserId = state.user.id;
                  // Auto-load if auth changes while on this page.
                  context.read<UsersBloc>().add(
                    GetPaginatedUsersEvent(_currentUserId!),
                  );
                }
              },
            ),

            // Listen to follower changes and update local list.
            BlocListener<FollowersBloc, FollowersState>(
              listener: (context, state) {
                if (state is UserFollowed) {
                  AppLogger.info(
                    'FollowersBloc -> Follow update: ${state.followedUserId} nowFollowing=${state.isFollowing}',
                  );
                  _handleFollowUpdate(state.followedUserId, state.isFollowing);
                } else if (state is FollowersError &&
                    _loadingUserIds.isNotEmpty) {
                  // Follow action failed
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
              // Show loading on initial or loading state
              if (state is UsersLoading || state is UsersInitial) {
                return const Center(child: LoadingIndicator());
              }

              // If we have UsersLoaded but list is empty -> show empty state
              if (state is UsersLoaded && state.users.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No users found yet.',
                  icon: Icons.people_outline,
                );
              }

              // If UsersError -> show error UI with retry
              if (state is UsersError) {
                return CustomErrorWidget(
                  message: 'Failed to load users:\n${state.message}',
                  onRetry: _retryFetch,
                );
              }

              // If UsersLoadMoreError -> show partial list with error for more
              if (state is UsersLoadMoreError) {
                return _buildListView(state.currentUsers, true, state.message);
              }

              // Otherwise show list (use bloc state)
              return _buildListView(
                (state as UsersLoaded).users,
                state.hasMore,
                null,
              );
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
    return ListView.separated(
      controller: _scrollController,
      itemCount: users.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        // Load more footer
        if (index == users.length) {
          if (loadMoreError != null) {
            return ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.red),
              title: Text('Load more failed: $loadMoreError'),
              trailing: TextButton(
                onPressed: () =>
                    context.read<UsersBloc>().add(const LoadMoreUsersEvent()),
                child: const Text('Retry'),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: LoadingIndicator()),
          );
        }

        final user = users[index];
        return UserListItem(
          key: ValueKey(user.id), // For performant list rebuilds
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
            // Optimistic update via event
            _handleFollowUpdate(followedId, isFollowing);
          },
        );
      },
    );
  }
}
