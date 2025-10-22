import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
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

  @override
  void initState() {
    super.initState();

    // Wait until first frame so context.read(...) is safe and blocs are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLoadUsers();
    });
  }

  void _maybeLoadUsers() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.id;
      AppLogger.info(
        'UsersPage: authenticated user id=$_currentUserId — dispatching GetAllUsersEvent',
      );
      context.read<UsersBloc>().add(GetAllUsersEvent(_currentUserId!));
    } else {
      AppLogger.warning(
        'UsersPage: no authenticated user available on init. authState=$authState',
      );
      // If auth becomes authenticated later, we also listen to it below via BlocListener.
    }
  }

  void _handleFollowUpdate(String followedUserId, bool nowFollowing) {
    setState(() {
      final index = _users.indexWhere((user) => user.id == followedUserId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(isFollowing: nowFollowing);
      } else {
        AppLogger.warning('Follow update for unknown user id=$followedUserId');
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to load users.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
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
              } else if (state is FollowersError) {
                AppLogger.error('FollowersBloc error: ${state.message}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Follow error: ${state.message}')),
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            } else if (state is UsersLoading) {
              AppLogger.info('UsersBloc -> UsersLoading');
            }
          },
          builder: (context, state) {
            // show loading while waiting
            if (state is UsersLoading || state is UsersInitial) {
              return const Center(child: LoadingIndicator());
            }

            // If we have UsersLoaded but list is empty -> show empty state
            if ((state is UsersLoaded && _users.isEmpty) || _users.isEmpty) {
              return EmptyStateWidget(
                message: 'No users found.',
                icon: Icons.people_outline,
              );
            }

            // If UsersError -> show error UI with retry
            if (state is UsersError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load users:\n${state.message}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retryFetch,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
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
                  onFollowToggle: (followedId, isFollowing) {
                    if (_currentUserId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'You must be signed in to follow users.',
                          ),
                        ),
                      );
                      return;
                    }
                    context.read<FollowersBloc>().add(
                      FollowUserEvent(
                        followerId: _currentUserId!,
                        followingId: followedId,
                        isFollowing: isFollowing,
                      ),
                    );
                    // Optimistic update can be applied here:
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
