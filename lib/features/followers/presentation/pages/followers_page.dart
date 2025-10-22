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
import 'package:vlone_blog_app/features/users/presentation/widgets/user_list_item.dart';

class FollowersPage extends StatefulWidget {
  final String userId;

  const FollowersPage({super.key, required this.userId});

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  List<UserListEntity> _users = [];
  String? _currentUserId;
  bool _isInitialLoad = true;
  final Set<String> _loadingUserIds = {};

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FollowersPage for user: ${widget.userId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _currentUserId = authState.user.id;
      }
      context.read<FollowersBloc>().add(
        GetFollowersEvent(userId: widget.userId, currentUserId: _currentUserId),
      );
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
    AppLogger.info('Retrying followers load for user: ${widget.userId}');
    setState(() {
      _isInitialLoad = true;
    });
    context.read<FollowersBloc>().add(
      GetFollowersEvent(userId: widget.userId, currentUserId: _currentUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                AppLogger.info(
                  'AuthBloc -> Authenticated in FollowersPage, userId=${state.user.id}',
                );
                if (_currentUserId == null) {
                  _currentUserId = state.user.id;
                  context.read<FollowersBloc>().add(
                    GetFollowersEvent(
                      userId: widget.userId,
                      currentUserId: _currentUserId,
                    ),
                  );
                }
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
        child: BlocConsumer<FollowersBloc, FollowersState>(
          listener: (context, state) {
            if (state is FollowersLoaded) {
              AppLogger.info(
                'Followers loaded with ${state.users.length} users for user: ${widget.userId}',
              );
              setState(() {
                _users = state.users;
                _isInitialLoad = false;
              });
            } else if (state is FollowersError && _isInitialLoad) {
              AppLogger.error('Followers load failed: ${state.message}');
              setState(() {
                _isInitialLoad = false;
              });
              SnackbarUtils.showError(context, state.message);
            }
          },
          builder: (context, state) {
            if (state is FollowersLoading && _isInitialLoad) {
              return const Center(child: LoadingIndicator());
            } else if (state is FollowersError && _users.isEmpty) {
              return CustomErrorWidget(
                message: state.message,
                onRetry: _retryFetch,
              );
            } else if (_users.isEmpty && !_isInitialLoad) {
              return const EmptyStateWidget(
                message: 'No followers yet.',
                icon: Icons.people_outline,
              );
            }
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
