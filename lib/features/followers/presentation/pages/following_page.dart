import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/presentation/widgets/user_list_item.dart';

class FollowingPage extends StatefulWidget {
  final String userId;

  const FollowingPage({super.key, required this.userId});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  List<UserListEntity> _users = [];
  String? _currentUserId;
  bool _isInitialLoad = true;
  final Set<String> _loadingUserIds = {};

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FollowingPage for user: ${widget.userId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _currentUserId = authState.user.id;
      }
      context.read<FollowersBloc>().add(
        GetFollowingEvent(userId: widget.userId, currentUserId: _currentUserId),
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
    AppLogger.info('Retrying following load for user: ${widget.userId}');
    setState(() {
      _isInitialLoad = true;
    });
    context.read<FollowersBloc>().add(
      GetFollowingEvent(userId: widget.userId, currentUserId: _currentUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                AppLogger.info(
                  'AuthBloc -> Authenticated in FollowingPage, userId=${state.user.id}',
                );
                if (_currentUserId == null) {
                  _currentUserId = state.user.id;
                  context.read<FollowersBloc>().add(
                    GetFollowingEvent(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Follow error: ${state.message}')),
                );
              }
            },
          ),
        ],
        child: BlocConsumer<FollowersBloc, FollowersState>(
          listener: (context, state) {
            if (state is FollowingLoaded) {
              AppLogger.info(
                'Following loaded with ${state.users.length} users for user: ${widget.userId}',
              );
              setState(() {
                _users = state.users;
                _isInitialLoad = false;
              });
            } else if (state is FollowersError && _isInitialLoad) {
              AppLogger.error('Following load failed: ${state.message}');
              setState(() {
                _isInitialLoad = false;
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          builder: (context, state) {
            if (state is FollowersLoading && _isInitialLoad) {
              return const Center(child: LoadingIndicator());
            } else if (state is FollowersError && _users.isEmpty) {
              return EmptyStateWidget(
                message: state.message,
                icon: Icons.error_outline,
                onRetry: _retryFetch,
                actionText: 'Retry',
              );
            } else if (_users.isEmpty && !_isInitialLoad) {
              return const EmptyStateWidget(
                message: 'Not following anyone yet.',
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'You must be signed in to follow users.',
                          ),
                        ),
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
