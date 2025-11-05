import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/presentation/widgets/cutsom_alert_dialog.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_overlay.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';

enum ProfileMenuOption { edit, settings, logout }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _currentUserId;
  bool _isLoadingMoreUserPosts = false;
  final ScrollController _scrollController = ScrollController();
  static const Duration _loadMoreDebounce = Duration(milliseconds: 300);

  // New flags to track listener state locally (Kept as mirrors for fallback logic)
  bool _isProfileRealtimeActive = false;
  bool _isUserPostsRealtimeActive = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.id;
    } else {
      _currentUserId = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeProfile();
      }
    });
  }

  void _initializeProfile() {
    if (_currentUserId == null) {
      AppLogger.error(
        'ProfilePage: User is not authenticated. Cannot initialize.',
      );
      return;
    }

    // Reset local realtime tracking flags
    _isProfileRealtimeActive = false;
    _isUserPostsRealtimeActive = false;

    context.read<ProfileBloc>().add(GetProfileDataEvent(_currentUserId!));
    context.read<UserPostsBloc>().add(
      RefreshUserPostsEvent(
        profileUserId: _currentUserId!,
        currentUserId: _currentUserId!,
      ),
    );

    AppLogger.info(
      'ProfilePage: Initialized for current user: $_currentUserId',
    );
  }

  // Fallback mechanism to ensure Realtime starts
  void _ensureProfileRealtimeActive(ProfileState state) {
    if (state is ProfileDataLoaded &&
        !_isProfileRealtimeActive &&
        _currentUserId != null) {
      AppLogger.warning(
        'ProfilePage: Profile Realtime was not active after load. Starting as fallback.',
      );
      context.read<ProfileBloc>().add(
        StartProfileRealtimeEvent(_currentUserId!),
      );
    }
  }

  void _ensureUserPostsRealtimeActive(UserPostsState state) {
    if (state is UserPostsLoaded &&
        !_isUserPostsRealtimeActive &&
        _currentUserId != null) {
      AppLogger.warning(
        'ProfilePage: UserPosts Realtime was not active after load. Starting as fallback.',
      );
      context.read<UserPostsBloc>().add(
        StartUserPostsRealtime(profileUserId: _currentUserId!),
      );
    }
  }

  Future<void> _onRefreshProfile() async {
    if (_currentUserId == null) return;

    // 1. Dispatch event to refresh the Profile
    context.read<ProfileBloc>().add(GetProfileDataEvent(_currentUserId!));

    // 2. Dispatch event to refresh the User Posts
    context.read<UserPostsBloc>().add(
      RefreshUserPostsEvent(
        profileUserId: _currentUserId!,
        currentUserId: _currentUserId!,
      ),
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      Debouncer.instance.debounce('load_more_user_posts', _loadMoreDebounce, () {
        final userPostsState = context.read<UserPostsBloc>().state;

        final bool hasMore = (userPostsState is UserPostsLoaded)
            ? userPostsState.hasMore
            : (userPostsState
                  is UserPostsLoadMoreError); // Allow retry on error

        // We check if posts have been loaded at least once by checking the state type
        final bool hasLoadedOnce =
            userPostsState is UserPostsLoaded ||
            userPostsState is UserPostsLoadingMore ||
            userPostsState is UserPostsLoadMoreError;

        if (_scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 200 &&
            hasMore &&
            !_isLoadingMoreUserPosts &&
            hasLoadedOnce) {
          if (!mounted) return;
          setState(() => _isLoadingMoreUserPosts = true);
          context.read<UserPostsBloc>().add(const LoadMoreUserPostsEvent());
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showLogoutConfirmationDialog() {
    // (Function body is unchanged)
    showCustomDialog(
      context: context,
      title: 'Logout Confirmation',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Are you sure you want to log out? You will need to sign in again to access your account.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
      isDismissible: false,
      actions: [
        DialogActions.createCancelButton(context, label: 'Cancel'),
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop(true);
            context.read<AuthBloc>().add(LogoutEvent());
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Authentication Required',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Please sign in to view your profile',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          SnackbarUtils.showError(context, state.message);
        }
      },
      builder: (context, authState) {
        final isLoggingOut = authState is AuthLoading;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text(
              'My Profile',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 4,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () {
                    context.push('${Constants.profileRoute}/me/edit');
                  },
                  icon: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  tooltip: 'Edit Profile',
                ),
              ),
              PopupMenuButton<ProfileMenuOption>(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onSelected: (value) {
                  switch (value) {
                    case ProfileMenuOption.edit:
                      context.push('${Constants.profileRoute}/me/edit');
                      break;
                    case ProfileMenuOption.settings:
                      context.push('${Constants.profileRoute}/me/settings');
                      break;
                    case ProfileMenuOption.logout:
                      _showLogoutConfirmationDialog();
                      break;
                  }
                },
                itemBuilder: (menuContext) {
                  final iconColor = Theme.of(menuContext).colorScheme.onSurface;
                  final textStyle = Theme.of(menuContext).textTheme.bodyMedium;
                  return [
                    PopupMenuItem<ProfileMenuOption>(
                      value: ProfileMenuOption.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: iconColor, size: 20),
                          const SizedBox(width: 12),
                          Text('Edit Profile', style: textStyle),
                        ],
                      ),
                    ),
                    PopupMenuItem<ProfileMenuOption>(
                      value: ProfileMenuOption.settings,
                      child: Row(
                        children: [
                          Icon(Icons.settings, color: iconColor, size: 20),
                          const SizedBox(width: 12),
                          Text('Settings', style: textStyle),
                        ],
                      ),
                    ),
                    PopupMenuItem<ProfileMenuOption>(
                      value: ProfileMenuOption.logout,
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: iconColor, size: 20),
                          const SizedBox(width: 12),
                          Text('Logout', style: textStyle),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              MultiBlocListener(
                listeners: [
                  BlocListener<ProfileBloc, ProfileState>(
                    listener: (context, state) {
                      if (state is ProfileDataLoaded) {
                        // Update local flag from BLoC state
                        _isProfileRealtimeActive = state.isRealtimeActive;

                        if (state.userId != _currentUserId) {
                          AppLogger.info(
                            'ProfilePage: ProfileBloc updated to foreign user (${state.userId}). Re-initializing.',
                          );
                          _initializeProfile();
                        } else {
                          AppLogger.info(
                            'Profile updated via real-time stream: ${state.profile.username}',
                          );
                          _ensureProfileRealtimeActive(state);
                        }
                      }
                    },
                  ),
                  BlocListener<UserPostsBloc, UserPostsState>(
                    listener: (context, state) {
                      if (state.profileUserId != null &&
                          state.profileUserId != _currentUserId) {
                        // Ignore state for foreign profile
                        AppLogger.info(
                          'ProfilePage: UserPostsBloc state is for foreign profile (${state.profileUserId}). Triggering refresh for $_currentUserId.',
                        );
                        context.read<UserPostsBloc>().add(
                          RefreshUserPostsEvent(
                            profileUserId: _currentUserId!,
                            currentUserId: _currentUserId!,
                          ),
                        );
                        return;
                      }

                      if (!mounted) return;

                      // Update Realtime status and stop loading indicators
                      if (state is UserPostsLoaded) {
                        _isUserPostsRealtimeActive = state.isRealtimeActive;
                        setState(() {
                          _isLoadingMoreUserPosts = false;
                        });
                        AppLogger.info(
                          'ProfilePage: UserPosts Loaded. Realtime Active: ${_isUserPostsRealtimeActive}',
                        );
                        _ensureUserPostsRealtimeActive(state);
                      } else if (state is UserPostsLoadMoreError) {
                        setState(() {
                          _isLoadingMoreUserPosts = false;
                        });
                      }
                      // Loading state is handled by the BlocBuilder (to show the initial spinner).
                      // We no longer need to manually copy lists or set hasMore/errors here.
                    },
                  ),
                  BlocListener<PostActionsBloc, PostActionsState>(
                    listenWhen: (previous, current) =>
                        current
                            is PostDeletedSuccess, // Only listen for deletion
                    listener: (context, state) {
                      if (state is PostDeletedSuccess) {
                        context.read<UserPostsBloc>().add(
                          RemovePostFromUserPosts(state.postId),
                        );
                      }
                    },
                  ),
                ],
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, profileState) {
                    if (profileState is ProfileLoading ||
                        profileState is ProfileInitial) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LoadingIndicator(size: 32),
                            SizedBox(height: 16),
                            Text(
                              'Loading profile...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (profileState is ProfileError) {
                      return CustomErrorWidget(
                        message: profileState.message,
                        onRetry: _onRefreshProfile,
                      );
                    }
                    if (profileState is ProfileDataLoaded) {
                      // Use a nested BlocBuilder to access UserPostsState
                      return RefreshIndicator(
                        onRefresh: _onRefreshProfile,
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: ProfileHeader(
                                profile: profileState.profile,
                                isOwnProfile: true,
                              ),
                            ),
                            BlocBuilder<UserPostsBloc, UserPostsState>(
                              builder: (context, userPostsState) {
                                List<PostEntity> posts = [];
                                bool isLoading = false;
                                String? error;
                                bool hasMore = false;
                                String? loadMoreError;

                                if (userPostsState is UserPostsLoading &&
                                    userPostsState.profileUserId ==
                                        _currentUserId) {
                                  isLoading = true;
                                } else if (userPostsState is UserPostsError &&
                                    userPostsState.profileUserId ==
                                        _currentUserId) {
                                  error = userPostsState.message;
                                } else if (userPostsState is UserPostsLoaded) {
                                  posts = userPostsState.posts;
                                  hasMore = userPostsState.hasMore;
                                } else if (userPostsState
                                    is UserPostsLoadingMore) {
                                  posts = userPostsState.posts;
                                  hasMore = true; // Still expecting more data
                                } else if (userPostsState
                                    is UserPostsLoadMoreError) {
                                  posts = userPostsState.posts;
                                  loadMoreError = userPostsState.message;
                                  hasMore = true; // Show retry button
                                }

                                return ProfilePostsList(
                                  posts: posts,
                                  userId: _currentUserId!,
                                  isLoading: isLoading,
                                  error: error,
                                  hasMore: hasMore,
                                  isLoadingMore:
                                      _isLoadingMoreUserPosts &&
                                      userPostsState
                                          is UserPostsLoadingMore, // Only show if BLoC is loading more
                                  loadMoreError: loadMoreError,
                                  onRetry: () {
                                    if (!mounted || _currentUserId == null)
                                      return;
                                    // No local state reset needed, just trigger refresh
                                    context.read<UserPostsBloc>().add(
                                      RefreshUserPostsEvent(
                                        profileUserId: _currentUserId!,
                                        currentUserId: _currentUserId!,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              if (isLoggingOut)
                const SavingLoadingOverlay(message: 'Logging out...'),
            ],
          ),
        );
      },
    );
  }
}
