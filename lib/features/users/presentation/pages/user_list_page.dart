import 'dart:async';

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
import 'package:vlone_blog_app/features/users/presentation/widgets/user_list_view.dart';

/// New: supports followers, following, and the 'all users' screen.
enum UserListMode { followers, following, users }

class UserListPage extends StatefulWidget {
  /// `userId` is required for followers/following modes, optional for users mode.
  final String? userId;
  final UserListMode mode;
  final String title;

  const UserListPage({
    super.key,
    this.userId,
    required this.mode,
    required this.title,
  });

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  String? _currentUserId;
  final Set<String> _loadingUserIds = {};

  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  Timer? _loadMoreDebounce;
  static const Duration _loadMoreDebounceDuration = Duration(milliseconds: 300);

  static const int _followersPageSize = FollowersBloc.defaultPageSize;

  @override
  void initState() {
    super.initState();
    AppLogger.info(
      'Initializing UserListPage (${widget.mode}) userId=${widget.userId}',
    );
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && mounted) {
        setState(() => _currentUserId = authState.user.id);
      }
      _fetchInitial();
    });
  }

  void _fetchInitial() {
    switch (widget.mode) {
      case UserListMode.followers:
        if (widget.userId == null) {
          AppLogger.error('UserListPage: followers mode requires userId');
          return;
        }
        context.read<FollowersBloc>().add(
          GetFollowersEvent(
            userId: widget.userId!,
            currentUserId: _currentUserId,
            pageSize: _followersPageSize,
            lastCreatedAt: null,
          ),
        );
        break;
      case UserListMode.following:
        if (widget.userId == null) {
          AppLogger.error('UserListPage: following mode requires userId');
          return;
        }
        context.read<FollowersBloc>().add(
          GetFollowingEvent(
            userId: widget.userId!,
            currentUserId: _currentUserId,
            pageSize: _followersPageSize,
            lastCreatedAt: null,
          ),
        );
        break;
      case UserListMode.users:
        // Users tab: use UsersBloc (currentUserId may be empty string if not set)
        context.read<UsersBloc>().add(
          GetPaginatedUsersEvent(_currentUserId ?? ''),
        );
        break;
    }
  }

  /// Handles the pull-to-refresh gesture for UserListMode.users.
  Future<void> _onRefresh() async {
    if (widget.mode == UserListMode.users) {
      // Use Completer to signal the RefreshIndicator when the BLoC operation finishes
      final completer = Completer<void>();
      context.read<UsersBloc>().add(
        RefreshUsersEvent(_currentUserId ?? '', completer),
      );
      return completer.future;
    }
    // No-op for followers/following
    return Future.value();
  }

  @override
  void dispose() {
    _loadMoreDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _loadMoreDebounce?.cancel();
    _loadMoreDebounce = Timer(_loadMoreDebounceDuration, () {
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) return;
      final threshold = position.maxScrollExtent * 0.9;
      if (position.pixels < threshold) return;

      if (widget.mode == UserListMode.users) {
        final usersState = context.read<UsersBloc>().state;
        if (usersState is UsersLoaded &&
            usersState.hasMore &&
            !_isLoadingMore) {
          setState(() => _isLoadingMore = true);
          context.read<UsersBloc>().add(const LoadMoreUsersEvent());
        } else if (usersState is UsersLoadMoreError && !_isLoadingMore) {
          // Allow retry by firing LoadMoreUsersEvent again
          setState(() => _isLoadingMore = true);
          context.read<UsersBloc>().add(const LoadMoreUsersEvent());
        }
        return;
      }

      // followers / following pagination
      final blocState = context.read<FollowersBloc>().state;
      List<UserListEntity> users = [];
      bool hasMore = true;

      if (blocState is FollowersLoaded) {
        users = blocState.users;
        hasMore = blocState.hasMore;
      } else if (blocState is FollowersLoadingMore) {
        users = blocState.users;
      } else if (blocState is FollowersLoadMoreError) {
        users = blocState.users;
      } else if (blocState is UserFollowed) {
        users = blocState.users;
        hasMore = blocState.hasMore;
      } else if (blocState is FollowOperationFailed) {
        users = blocState.users;
        hasMore = blocState.hasMore;
      } else {
        return;
      }

      if (!hasMore) return;
      if (_isLoadingMore) return;
      if (users.isEmpty) return;

      setState(() => _isLoadingMore = true);
      final last = users.last;
      if (widget.mode == UserListMode.followers) {
        context.read<FollowersBloc>().add(
          GetFollowersEvent(
            userId: widget.userId!,
            currentUserId: _currentUserId,
            pageSize: _followersPageSize,
            lastCreatedAt: last.createdAt,
            lastId: last.id,
          ),
        );
      } else {
        context.read<FollowersBloc>().add(
          GetFollowingEvent(
            userId: widget.userId!,
            currentUserId: _currentUserId,
            pageSize: _followersPageSize,
            lastCreatedAt: last.createdAt,
            lastId: last.id,
          ),
        );
      }
    });
  }

  void _onFollowToggle(String followedId, bool isFollowing) {
    if (_currentUserId == null) {
      SnackbarUtils.showError(
        context,
        'You must be signed in to follow users.',
      );
      return;
    }

    // Show spinner on that item
    setState(() => _loadingUserIds.add(followedId));

    // If users-mode: optimistic update UsersBloc, then call FollowersBloc to perform the network mutate.
    if (widget.mode == UserListMode.users) {
      // Optimistic update
      context.read<UsersBloc>().add(
        UpdateUserFollowStatusEvent(followedId, isFollowing),
      );

      // Trigger network follow/unfollow via FollowersBloc
      context.read<FollowersBloc>().add(
        FollowUserEvent(
          followerId: _currentUserId!,
          followingId: followedId,
          isFollowing: isFollowing,
        ),
      );

      return;
    }

    // If followers/following modes: FollowersBloc owns the list. Dispatch FollowUserEvent directly.
    context.read<FollowersBloc>().add(
      FollowUserEvent(
        followerId: _currentUserId!,
        followingId: followedId,
        isFollowing: isFollowing,
      ),
    );
  }

  void _retryFetch() {
    AppLogger.info(
      'Retrying list load for ${widget.userId} mode=${widget.mode}',
    );
    _fetchInitial();
  }

  @override
  Widget build(BuildContext context) {
    // Build the listeners list dynamically so UsersBloc listener is only added when needed.
    final listeners = <BlocListenerBase>[
      BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            AppLogger.info(
              'AuthBloc -> Authenticated in UserListPage, userId=${state.user.id}',
            );
            if (_currentUserId == null) {
              setState(() => _currentUserId = state.user.id);
              _retryFetch();
            }
          }
        },
      ),

      // FollowersBloc listener (handles follow confirmations & failures)
      BlocListener<FollowersBloc, FollowersState>(
        listener: (context, state) {
          // When follow completes, remove loading indicator for that id
          if (state is UserFollowed) {
            setState(() => _loadingUserIds.remove(state.followedUserId));
          }

          // If a follow operation failed, revert optimistic change (if users-mode) and show snackbar
          if (state is FollowOperationFailed) {
            setState(() => _loadingUserIds.remove(state.followedUserId));

            // If users-mode, revert UsersBloc optimistic update
            if (widget.mode == UserListMode.users) {
              try {
                context.read<UsersBloc>().add(
                  UpdateUserFollowStatusEvent(
                    state.followedUserId,
                    !state.attemptedIsFollowing,
                  ),
                );
              } catch (_) {}
            }

            SnackbarUtils.showError(context, 'Follow failed: ${state.message}');
          }

          // Generic error handling for loading/pagination
          if (state is FollowersError) {
            setState(() {
              _loadingUserIds.clear();
              _isLoadingMore = false;
            });
            SnackbarUtils.showError(context, state.message);
          } else if (state is FollowersLoadMoreError) {
            setState(() => _isLoadingMore = false);
            SnackbarUtils.showError(context, state.message);
          } else if (state is FollowersLoaded) {
            setState(() => _isLoadingMore = false);
          }
        },
      ),
    ];

    // Add UsersBloc listener only when in users mode (prevents ProviderNotFoundException
    // when this page is provided with only FollowersBloc, e.g. followers/following routes).
    if (widget.mode == UserListMode.users) {
      listeners.add(
        BlocListener<UsersBloc, UsersState>(
          listener: (context, state) {
            // Dismiss the RefreshIndicator by completing the completer
            final completer = (state is UsersLoaded)
                ? state.refreshCompleter
                : (state is UsersError)
                ? state.refreshCompleter
                : null;
            completer?.complete();

            // Handle general state changes/errors for users mode
            if (state is UsersLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isLoadingMore = false);
              });
            } else if (state is UsersLoadMoreError || state is UsersError) {
              // Load more error is handled in the footer widget
              if (state is UsersError && state.users.isNotEmpty) {
                // Show snackbar if initial load failed but we had previous data
                SnackbarUtils.showError(context, state.message);
              }
              setState(() => _isLoadingMore = false);
            }
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: MultiBlocListener(
        listeners: listeners,
        child: Builder(
          builder: (context) {
            // Branch UI based on mode
            if (widget.mode == UserListMode.users) {
              // UsersBloc-driven UI (WITH RefreshIndicator)
              return BlocBuilder<UsersBloc, UsersState>(
                builder: (context, state) {
                  if (state is UsersLoading || state is UsersInitial) {
                    // If the list is empty, show full screen loading
                    if (state is UsersLoading &&
                        context.read<UsersBloc>().state is! UsersLoaded) {
                      return const Center(child: LoadingIndicator());
                    }
                    // Otherwise, the RefreshIndicator will show for a loading state
                    if (state is UsersInitial) {
                      return const Center(child: LoadingIndicator());
                    }
                  }

                  // Handle cases where we have a list to show, possibly with error/loading footer
                  List<UserListEntity> users = [];
                  bool hasMore = false;
                  String? loadMoreError;

                  if (state is UsersLoadMoreError) {
                    users = state.currentUsers;
                    hasMore = true; // Assume true to show load more error
                    loadMoreError = state.message;
                  } else if (state is UsersLoadingMore) {
                    users = state.currentUsers;
                    hasMore = true;
                  } else if (state is UsersLoaded) {
                    users = state.users;
                    hasMore = state.hasMore;
                  } else if (state is UsersError) {
                    users = state.users;
                    hasMore = false;
                    // If no users were fetched at all, show the error widget
                    if (users.isEmpty) {
                      return CustomErrorWidget(
                        message: 'Failed to load users:\n${state.message}',
                        onRetry: _retryFetch,
                      );
                    }
                  } else if (state is UsersInitial) {
                    // Should be handled by initial loading, but fallback for safety
                    return const Center(child: LoadingIndicator());
                  }

                  if (users.isEmpty) {
                    return EmptyStateWidget(
                      message: 'No users found',
                      icon: Icons.people_outline,
                      actionText: 'Refresh',
                      onRetry: _retryFetch,
                    );
                  }

                  // Build the list view wrapped in RefreshIndicator using the reusable UserListView
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: UserListView(
                      controller: _scrollController,
                      users: users,
                      hasMore: hasMore,
                      loadMoreError: loadMoreError,
                      loadingUserIds: _loadingUserIds,
                      currentUserId: _currentUserId ?? '',
                      onFollowToggle: (followedId, isFollowing) {
                        _onFollowToggle(followedId, isFollowing);
                      },
                      onRetryLoadMore: () {
                        setState(() => _isLoadingMore = true);
                        context.read<UsersBloc>().add(
                          const LoadMoreUsersEvent(),
                        );
                      },
                    ),
                  );
                },
              );
            }

            // Followers/following UI (FollowersBloc) - NO RefreshIndicator
            return BlocBuilder<FollowersBloc, FollowersState>(
              builder: (context, state) {
                bool isInitialLoading = false;
                List<UserListEntity> users = [];
                bool hasMore = false;
                String? loadMoreError;

                if (state is FollowersLoading) {
                  isInitialLoading = true;
                } else if (state is FollowersLoaded) {
                  users = state.users;
                  hasMore = state.hasMore;
                } else if (state is FollowersLoadingMore) {
                  users = state.users;
                } else if (state is FollowersLoadMoreError) {
                  users = state.users;
                  loadMoreError = state.message;
                } else if (state is UserFollowed) {
                  users = state.users;
                  hasMore = state.hasMore;
                } else if (state is FollowOperationFailed) {
                  users = state.users;
                  hasMore = state.hasMore;
                }

                if (isInitialLoading) {
                  return const Center(child: LoadingIndicator());
                }

                if (state is FollowersError && users.isEmpty) {
                  return CustomErrorWidget(
                    message: state.message,
                    onRetry: _retryFetch,
                  );
                }

                if (users.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No users yet.',
                    icon: Icons.people_outline,
                  );
                }

                // reset loading-more flag
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _isLoadingMore = false);
                });

                // Use the reusable UserListView here too. Provide an onRetryLoadMore that
                // dispatches the appropriate FollowersBloc pagination event using the last user.
                return UserListView(
                  controller: _scrollController,
                  users: users,
                  hasMore: hasMore,
                  loadMoreError: loadMoreError,
                  loadingUserIds: _loadingUserIds,
                  currentUserId: _currentUserId ?? '',
                  onFollowToggle: (followedId, isFollowing) {
                    _onFollowToggle(followedId, isFollowing);
                  },
                  onRetryLoadMore: () {
                    final lastUser = users.isNotEmpty ? users.last : null;
                    if (lastUser == null) return;
                    setState(() => _isLoadingMore = true);
                    if (widget.mode == UserListMode.followers) {
                      context.read<FollowersBloc>().add(
                        GetFollowersEvent(
                          userId: widget.userId!,
                          currentUserId: _currentUserId,
                          pageSize: _followersPageSize,
                          lastCreatedAt: lastUser.createdAt,
                          lastId: lastUser.id,
                        ),
                      );
                    } else {
                      context.read<FollowersBloc>().add(
                        GetFollowingEvent(
                          userId: widget.userId!,
                          currentUserId: _currentUserId,
                          pageSize: _followersPageSize,
                          lastCreatedAt: lastUser.createdAt,
                          lastId: lastUser.id,
                        ),
                      );
                    }
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
