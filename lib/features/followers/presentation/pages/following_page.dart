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

  // --- Pagination State ---
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  final int _pageSize = FollowersBloc.defaultPageSize;
  // ------------------------

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FollowingPage for user: ${widget.userId}');

    // Add scroll listener
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _currentUserId = authState.user.id;
      }
      _fetchInitialFollowing();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchInitialFollowing() {
    context.read<FollowersBloc>().add(
      GetFollowingEvent(
        userId: widget.userId,
        currentUserId: _currentUserId,
        pageSize: _pageSize,
      ),
    );
  }

  void _onScroll() {
    // Check if we are at the bottom and not already loading
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _hasNextPage &&
        _users.isNotEmpty) {
      AppLogger.info('Fetching more following...');
      setState(() {
        _isLoadingMore = true;
      });

      final lastUser = _users.last;
      context.read<FollowersBloc>().add(
        GetFollowingEvent(
          userId: widget.userId,
          currentUserId: _currentUserId,
          pageSize: _pageSize,
          lastCreatedAt:
              lastUser.createdAt, // Assumes UserListEntity has createdAt
          lastId: lastUser.id,
        ),
      );
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
      _loadingUserIds.remove(followedUserId);
    });
  }

  void _retryFetch() {
    AppLogger.info('Retrying following load for user: ${widget.userId}');
    setState(() {
      _isInitialLoad = true;
      // Reset pagination state
      _users = [];
      _hasNextPage = true;
      _isLoadingMore = false;
    });
    _fetchInitialFollowing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
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
                  _retryFetch(); // Use retryFetch to reset state
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
            if (state is FollowingLoaded) {
              // --- Initial Load ---
              AppLogger.info(
                'Initial following loaded with ${state.users.length} users for user: ${widget.userId}',
              );
              setState(() {
                _users = state.users;
                _isInitialLoad = false;
                _isLoadingMore = false;
                // Check if this page is full
                _hasNextPage = state.users.length == _pageSize;
              });
            } else if (state is FollowingMoreLoaded) {
              // --- Paginated Load ---
              AppLogger.info(
                'More following loaded with ${state.users.length} users',
              );
              setState(() {
                _users.addAll(state.users);
                _isLoadingMore = false;
                // Check if this page is full
                _hasNextPage = state.users.length == _pageSize;
              });
            } else if (state is FollowersError) {
              AppLogger.error('Following load failed: ${state.message}');
              if (_isInitialLoad) {
                // --- Initial Load Error ---
                setState(() {
                  _isInitialLoad = false;
                });
                SnackbarUtils.showError(context, state.message);
              } else if (_isLoadingMore) {
                // --- Paginated Load Error ---
                setState(() {
                  _isLoadingMore = false;
                  // Don't set _hasNextPage to false, allow user to retry by scrolling
                });
                SnackbarUtils.showError(
                  context,
                  'Failed to load more users: ${state.message}',
                );
              }
            }
          },
          builder: (context, state) {
            if (state is FollowersLoading && _isInitialLoad) {
              return const Center(child: LoadingIndicator());
            } else if (state is FollowersError &&
                _users.isEmpty &&
                !_isLoadingMore) {
              return CustomErrorWidget(
                message: state.message,
                onRetry: _retryFetch,
              );
            } else if (_users.isEmpty && !_isInitialLoad && !_isLoadingMore) {
              return const EmptyStateWidget(
                message: 'Not following anyone yet.',
                icon: Icons.people_outline,
              );
            }

            // --- Updated ListView ---
            return ListView.builder(
              controller: _scrollController,
              // Add 1 to item count for the loading indicator if we are loading more
              itemCount: _users.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // --- Show loading indicator at the bottom ---
                if (index == _users.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: LoadingIndicator(),
                    ),
                  );
                }

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
