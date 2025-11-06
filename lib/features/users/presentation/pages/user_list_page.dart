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

/// Defines the three possible modes for the user list page.
enum UserListMode {
  /// Displays users who follow a specific `userId`.
  followers,

  /// Displays users followed by a specific `userId`.
  following,

  /// Displays a paginated list of all users in the application (discovery).
  users,
}

/// A versatile page for displaying lists of users based on three modes:
/// followers, following, or general discovery.
///
/// It uses either the [FollowersBloc] or [UsersBloc] depending on the selected [mode],
/// implements infinite scrolling with debouncing, and handles optimistic UI updates
/// for follow/unfollow actions.
class UserListPage extends StatefulWidget {
  /// The user ID relevant to the list (required for followers/following modes).
  final String? userId;

  /// The operational mode defining the data source and logic.
  final UserListMode mode;

  /// The title displayed in the AppBar.
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

  /// Tracks users that are currently undergoing a network follow/unfollow operation
  /// to display a loading indicator on the list item.
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

    // Initial check for authenticated user ID and data fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && mounted) {
        setState(() => _currentUserId = authState.user.id);
      }
      _fetchInitial();
    });
  }

  /// Dispatches the initial BLoC event based on the current [UserListMode].
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
        // Users mode uses UsersBloc for general discovery
        context.read<UsersBloc>().add(
          GetPaginatedUsersEvent(_currentUserId ?? ''),
        );
        break;
    }
  }

  /// Handles the pull-to-refresh gesture, currently only implemented for
  /// [UserListMode.users] which uses the [UsersBloc].
  Future<void> _onRefresh() async {
    if (widget.mode == UserListMode.users) {
      final completer = Completer<void>();
      context.read<UsersBloc>().add(
        RefreshUsersEvent(_currentUserId ?? '', completer),
      );
      return completer.future;
    }
    // No-op for followers/following lists as they don't typically support pull-to-refresh.
    return Future.value();
  }

  @override
  void dispose() {
    _loadMoreDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Handles scroll events for infinite loading with debouncing.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _loadMoreDebounce?.cancel();

    // Debouncing the scroll check to avoid excessive event dispatches
    _loadMoreDebounce = Timer(_loadMoreDebounceDuration, () {
      final position = _scrollController.position;
      // Exit if list is not scrollable (maxScrollExtent <= 0) or user is not near the end
      if (position.maxScrollExtent <= 0) return;
      final threshold = position.maxScrollExtent * 0.9;
      if (position.pixels < threshold) return;

      // --- UsersBloc Pagination (UserListMode.users) ---
      if (widget.mode == UserListMode.users) {
        final usersState = context.read<UsersBloc>().state;
        final shouldLoadMore =
            (usersState is UsersLoaded && usersState.hasMore) ||
            (usersState is UsersLoadMoreError);

        if (shouldLoadMore && !_isLoadingMore) {
          setState(() => _isLoadingMore = true);
          context.read<UsersBloc>().add(const LoadMoreUsersEvent());
        }
        return;
      }

      // --- FollowersBloc Pagination (Followers/Following modes) ---
      final blocState = context.read<FollowersBloc>().state;
      List<UserListEntity> users = [];
      bool hasMore = false;

      // Extract current data from the relevant state
      if (blocState is FollowersLoaded) {
        users = blocState.users;
        hasMore = blocState.hasMore;
      } else if (blocState is FollowersLoadingMore) {
        users = blocState.users;
        hasMore = true;
      } else if (blocState is FollowersLoadMoreError) {
        users = blocState.users;
        hasMore = true;
      } else if (blocState is UserFollowed) {
        users = blocState.users;
        hasMore = blocState.hasMore;
      } else if (blocState is FollowOperationFailed) {
        users = blocState.users;
        hasMore = blocState.hasMore;
      } else {
        return;
      }

      if (!hasMore || _isLoadingMore || users.isEmpty) return;

      setState(() => _isLoadingMore = true);
      final last = users.last;

      // Dispatch the appropriate Load More event using the last item's pagination keys
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

  /// Handles the user attempting to follow or unfollow another user.
  void _onFollowToggle(String followedId, bool isFollowing) {
    if (_currentUserId == null) {
      SnackbarUtils.showError(
        context,
        'You must be signed in to follow users.',
      );
      return;
    }

    // Set loading state for the specific item
    setState(() => _loadingUserIds.add(followedId));

    // For the general Users list (discovery)
    if (widget.mode == UserListMode.users) {
      // 1. Optimistic update the UsersBloc list immediately
      context.read<UsersBloc>().add(
        UpdateUserFollowStatusEvent(followedId, isFollowing),
      );

      // 2. Trigger the network operation via FollowersBloc (the network layer)
      context.read<FollowersBloc>().add(
        FollowUserEvent(
          followerId: _currentUserId!,
          followingId: followedId,
          isFollowing: isFollowing,
        ),
      );

      return;
    }

    // For followers/following lists, FollowersBloc manages the list state directly
    context.read<FollowersBloc>().add(
      FollowUserEvent(
        followerId: _currentUserId!,
        followingId: followedId,
        isFollowing: isFollowing,
      ),
    );
  }

  /// Re-initiates the initial data fetch. Used for retry buttons.
  void _retryFetch() {
    AppLogger.info(
      'Retrying list load for ${widget.userId} mode=${widget.mode}',
    );
    _fetchInitial();
  }

  // --- UI Building Methods ---

  @override
  Widget build(BuildContext context) {
    // --- BLoC Listeners ---
    // A dynamic list of listeners to handle cross-BLoC communication and state feedback
    final listeners = <BlocListenerBase>[
      // Listener for Auth status changes (e.g., if user signs in while on the page)
      BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            AppLogger.info(
              'AuthBloc -> Authenticated in UserListPage, userId=${state.user.id}',
            );
            if (_currentUserId == null) {
              setState(() => _currentUserId = state.user.id);
              _retryFetch(); // Re-fetch lists now that currentUserId is known
            }
          }
        },
      ),

      // Listener for FollowersBloc (handles follow confirmations, failures, and general errors)
      BlocListener<FollowersBloc, FollowersState>(
        listener: (context, state) {
          // Follow success: remove local loading state
          if (state is UserFollowed) {
            setState(() => _loadingUserIds.remove(state.followedUserId));
          }

          // Follow failure: revert UI (if users mode) and show error
          if (state is FollowOperationFailed) {
            setState(() => _loadingUserIds.remove(state.followedUserId));

            // If in users mode, revert the optimistic update in UsersBloc
            if (widget.mode == UserListMode.users) {
              try {
                context.read<UsersBloc>().add(
                  UpdateUserFollowStatusEvent(
                    state.followedUserId,
                    !state.attemptedIsFollowing, // Revert to previous status
                  ),
                );
              } catch (_) {
                AppLogger.error(
                  'Failed to revert optimistic update in UsersBloc.',
                );
              }
            }
            SnackbarUtils.showError(context, 'Follow failed: ${state.message}');
          }

          // Update loading state based on general list fetching
          if (state is FollowersError || state is FollowersLoadMoreError) {
            setState(() {
              _loadingUserIds.clear();
              _isLoadingMore = false;
            });
            if (state is FollowersError) {
              SnackbarUtils.showError(context, state.message);
            } else if (state is FollowersLoadMoreError) {
              SnackbarUtils.showError(context, state.message);
            }
          } else if (state is FollowersLoaded) {
            setState(() => _isLoadingMore = false);
          }
        },
      ),
    ];

    // Conditionally add UsersBloc listener only for `UserListMode.users`
    if (widget.mode == UserListMode.users) {
      listeners.add(
        BlocListener<UsersBloc, UsersState>(
          listener: (context, state) {
            // Complete the RefreshIndicator logic
            final completer = (state is UsersLoaded)
                ? state.refreshCompleter
                : (state is UsersError)
                ? state.refreshCompleter
                : null;
            completer?.complete();

            // Handle general state changes/errors for users mode pagination
            if (state is UsersLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isLoadingMore = false);
              });
            } else if (state is UsersLoadMoreError || state is UsersError) {
              if (state is UsersError && state.users.isNotEmpty) {
                // Show a non-blocking snackbar if initial load failed but we have stale data
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
            // --- UI for UserListMode.users (UsersBloc) ---
            if (widget.mode == UserListMode.users) {
              return BlocBuilder<UsersBloc, UsersState>(
                builder: (context, state) {
                  // Full-screen loading indicator for initial fetch
                  if (state is UsersLoading || state is UsersInitial) {
                    return const Center(child: LoadingIndicator());
                  }

                  // Data extraction from UsersBloc states
                  List<UserListEntity> users = [];
                  bool hasMore = false;
                  String? loadMoreError;

                  if (state is UsersLoadMoreError) {
                    users = state.currentUsers;
                    hasMore = true;
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
                    // Full-screen error state if no data was fetched
                    if (users.isEmpty) {
                      return CustomErrorWidget(
                        message: 'Failed to load users:\n${state.message}',
                        onRetry: _retryFetch,
                      );
                    }
                  }

                  // Empty State
                  if (users.isEmpty) {
                    return EmptyStateWidget(
                      message: 'No users found',
                      icon: Icons.people_outline,
                      actionText: 'Refresh',
                      onRetry: _retryFetch,
                    );
                  }

                  // Main List View with Pull-to-Refresh
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: UserListView(
                      controller: _scrollController,
                      users: users,
                      hasMore: hasMore,
                      loadMoreError: loadMoreError,
                      loadingUserIds: _loadingUserIds,
                      currentUserId: _currentUserId ?? '',
                      onFollowToggle: _onFollowToggle,
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

            // --- UI for Followers/Following (FollowersBloc) ---
            return BlocBuilder<FollowersBloc, FollowersState>(
              builder: (context, state) {
                bool isInitialLoading = false;
                List<UserListEntity> users = [];
                bool hasMore = false;
                String? loadMoreError;

                // Data extraction from FollowersBloc states
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

                // Initial Loading State
                if (isInitialLoading) {
                  return const Center(child: LoadingIndicator());
                }

                // Full-screen Error State
                if (state is FollowersError && users.isEmpty) {
                  return CustomErrorWidget(
                    message: state.message,
                    onRetry: _retryFetch,
                  );
                }

                // Empty State
                if (users.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No users yet.',
                    icon: Icons.people_outline,
                  );
                }

                // Reset loading-more flag after a successful load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _isLoadingMore = false);
                });

                // Main List View (No RefreshIndicator in this mode)
                return UserListView(
                  controller: _scrollController,
                  users: users,
                  hasMore: hasMore,
                  loadMoreError: loadMoreError,
                  loadingUserIds: _loadingUserIds,
                  currentUserId: _currentUserId ?? '',
                  onFollowToggle: _onFollowToggle,
                  onRetryLoadMore: () {
                    final lastUser = users.isNotEmpty ? users.last : null;
                    if (lastUser == null) return;
                    setState(() => _isLoadingMore = true);

                    // Re-dispatch the appropriate initial event for retry pagination
                    final event = widget.mode == UserListMode.followers
                        ? GetFollowersEvent(
                            userId: widget.userId!,
                            currentUserId: _currentUserId,
                            pageSize: _followersPageSize,
                            lastCreatedAt: lastUser.createdAt,
                            lastId: lastUser.id,
                          )
                        : GetFollowingEvent(
                            userId: widget.userId!,
                            currentUserId: _currentUserId,
                            pageSize: _followersPageSize,
                            lastCreatedAt: lastUser.createdAt,
                            lastId: lastUser.id,
                          );
                    context.read<FollowersBloc>().add(event);
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
