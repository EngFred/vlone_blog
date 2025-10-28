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
  List<UserListEntity> _users = [];
  final Set<String> _loadingUserIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && mounted) {
        setState(() => _currentUserId = authState.user.id);
        AppLogger.info('UsersPage: Set currentUserId=$_currentUserId');
      }
      // No dispatch here—let MainPage handle it.
    });
  }

  void _handleFollowUpdate(String followedUserId, bool nowFollowing) {
    setState(() {
      final index = _users.indexWhere((user) => user.id == followedUserId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(isFollowing: nowFollowing);
      } else {
        AppLogger.warning('Follow update for unknown user id=$followedUserId');
      }
      _loadingUserIds.remove(followedUserId);
    });
  }

  void _retryFetch() {
    if (_currentUserId != null) {
      AppLogger.info('Retrying fetch users for $_currentUserId');
      context.read<UsersBloc>().add(GetAllUsersEvent(_currentUserId!));
    } else {
      AppLogger.warning(
        'Retry attempted but currentUserId is null — ask AuthBloc to provide user or sign-in.',
      );
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _currentUserId = authState.user.id;
        context.read<UsersBloc>().add(GetAllUsersEvent(_currentUserId!));
      } else {
        SnackbarUtils.showError(
          context,
          'You must be signed in to load users.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: MultiBlocListener(
        listeners: [
          // Listen to Auth state so if the user signs in after this page was created we fetch users.
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                AppLogger.info(
                  'AuthBloc -> Authenticated in UsersPage, userId=${state.user.id}',
                );
                _currentUserId = state.user.id;
                // Optional: Auto-load if auth changes while on this page.
                context.read<UsersBloc>().add(
                  GetAllUsersEvent(_currentUserId!),
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
                setState(() {
                  _loadingUserIds.clear();
                });
                SnackbarUtils.showError(
                  context,
                  'Follow error: ${state.message}',
                );
              }
            },
          ),
        ],
        child: BlocConsumer<UsersBloc, UsersState>(
          listener: (context, state) {
            if (state is UsersLoaded) {
              AppLogger.info(
                'UsersBloc -> UsersLoaded with ${state.users.length} users',
              );
              setState(() {
                _users = state.users;
              });
            } else if (state is UsersError) {
              AppLogger.error('UsersBloc -> UsersError: ${state.message}');
              // show snackbar
              SnackbarUtils.showError(context, state.message);
            } else if (state is UsersLoading) {
              AppLogger.info('UsersBloc -> UsersLoading');
            }
          },
          builder: (context, state) {
            // Show loading on initial or loading state
            if (state is UsersLoading || state is UsersInitial) {
              return const Center(child: LoadingIndicator());
            }

            // If we have UsersLoaded but list is empty -> show empty state
            if (state is UsersLoaded && _users.isEmpty) {
              return const EmptyStateWidget(
                message: 'No users found.',
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

            // Otherwise show list (use local _users which is kept in sync)
            return ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _users[index];
                return UserListItem(
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
                    setState(() {
                      _loadingUserIds.add(followedId);
                    });
                    context.read<FollowersBloc>().add(
                      FollowUserEvent(
                        followerId: _currentUserId!,
                        followingId: followedId,
                        isFollowing: isFollowing,
                      ),
                    );
                    // Optimistic update
                    _handleFollowUpdate(followedId, isFollowing);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
