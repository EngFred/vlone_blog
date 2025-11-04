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
  final List<PostEntity> _userPosts = [];
  bool _hasMoreUserPosts = true;
  bool _isUserPostsLoading = true;
  bool _isLoadingMoreUserPosts = false;
  String? _userPostsError;
  String? _loadMoreError;
  final ScrollController _scrollController = ScrollController();
  static const Duration _loadMoreDebounce = Duration(milliseconds: 300);
  bool _hasLoadedOnce = false;

  // New flags to track listener state locally
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

    if (_userPosts.isEmpty && _isUserPostsLoading == false) {
      setState(() {
        _isUserPostsLoading = true;
      });
    }

    _userPosts.clear();
    _userPostsError = null;
    _loadMoreError = null;
    _hasMoreUserPosts = true;
    _hasLoadedOnce = false;
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

  // +++ NEW: Fallback mechanism to ensure Realtime starts +++
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
  // +++ END NEW +++

  // New method to handle the RefreshIndicator logic
  Future<void> _onRefreshProfile() async {
    if (_currentUserId == null) return;

    // 1. Dispatch event to refresh the Profile (the fix for the user request)
    context.read<ProfileBloc>().add(GetProfileDataEvent(_currentUserId!));

    // 2. Dispatch event to refresh the User Posts
    context.read<UserPostsBloc>().add(
      RefreshUserPostsEvent(
        profileUserId: _currentUserId!,
        currentUserId: _currentUserId!,
      ),
    );

    // 3. Reset local state for the post list to show a fresh loading indicator
    if (!mounted) return;
    setState(() {
      _userPosts.clear();
      _userPostsError = null;
      _hasMoreUserPosts = true;
      _isUserPostsLoading = true;
      _hasLoadedOnce = false;
      // Realtime active flags are not reset here, as they are either already
      // active or will be checked again upon the subsequent 'Loaded' state.
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      Debouncer.instance.debounce(
        'load_more_user_posts',
        _loadMoreDebounce,
        () {
          if (!_hasLoadedOnce) return;
          if (_scrollController.position.pixels >=
                  _scrollController.position.maxScrollExtent - 200 &&
              _hasMoreUserPosts &&
              !_isLoadingMoreUserPosts) {
            if (!mounted) return;
            setState(() => _isLoadingMoreUserPosts = true);
            context.read<UserPostsBloc>().add(LoadMoreUserPostsEvent());
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showLogoutConfirmationDialog() {
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
                          // +++ NEW: Check for fallback +++
                          _ensureProfileRealtimeActive(state);
                          // +++ END NEW +++
                        }
                      }
                    },
                  ),
                  BlocListener<UserPostsBloc, UserPostsState>(
                    listener: (context, state) {
                      if (state is UserPostsLoaded) {
                        // Update local flag from BLoC state
                        _isUserPostsRealtimeActive = state.isRealtimeActive;

                        if (state.profileUserId != null &&
                            state.profileUserId != _currentUserId) {
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
                        setState(() {
                          _userPosts.clear();
                          _userPostsError = null;
                          _userPosts.addAll(state.posts);
                          _hasMoreUserPosts = state.hasMore;
                          _isUserPostsLoading = false;
                          _isLoadingMoreUserPosts = false;
                          _loadMoreError = null;
                          _hasLoadedOnce = true;
                        });
                        AppLogger.info(
                          'ProfilePage: Loaded ${_userPosts.length} posts for $_currentUserId',
                        );
                        // +++ NEW: Check for fallback +++
                        _ensureUserPostsRealtimeActive(state);
                        // +++ END NEW +++
                      } else if (state is UserPostsError) {
                        if (state.profileUserId != null &&
                            state.profileUserId != _currentUserId) {
                          return;
                        }
                        if (!mounted) return;
                        setState(() {
                          _userPostsError = state.message;
                          _isUserPostsLoading = false;
                          _isLoadingMoreUserPosts = false;
                        });
                      } else if (state is UserPostsLoading) {
                        if (state.profileUserId != null &&
                            state.profileUserId != _currentUserId) {
                          return;
                        }
                        if (!mounted) return;
                        setState(() => _isUserPostsLoading = true);
                      } else if (state is UserPostsLoadMoreError) {
                        if (state.profileUserId != null &&
                            state.profileUserId != _currentUserId) {
                          return;
                        }
                        if (!mounted) return;
                        setState(() {
                          _loadMoreError = state.message;
                          _isLoadingMoreUserPosts = false;
                        });
                      }
                    },
                  ),
                  BlocListener<PostActionsBloc, PostActionsState>(
                    listenWhen: (previous, current) =>
                        current is PostCreatedSuccess ||
                        current is PostDeletedSuccess,
                    listener: (context, state) {
                      if (state is PostCreatedSuccess) {
                        // real time updates will hanlde this anyway
                      } else if (state is PostDeletedSuccess) {
                        context.read<UserPostsBloc>().add(
                          RemovePostFromUserPosts(state.postId),
                        );
                      }
                    },
                  ),
                ],
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    if (state is ProfileLoading || state is ProfileInitial) {
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
                    if (state is ProfileError) {
                      return CustomErrorWidget(
                        message: state.message,
                        onRetry: () =>
                            _onRefreshProfile(), // Use new refresh method on retry
                      );
                    }
                    if (state is ProfileDataLoaded) {
                      return RefreshIndicator(
                        onRefresh: _onRefreshProfile, // Use the new method
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: ProfileHeader(
                                profile: state.profile,
                                isOwnProfile: true,
                              ),
                            ),
                            ProfilePostsList(
                              posts: _userPosts,
                              userId: _currentUserId!,
                              isLoading: _isUserPostsLoading,
                              error: _userPostsError,
                              hasMore: _hasMoreUserPosts,
                              isLoadingMore: _isLoadingMoreUserPosts,
                              loadMoreError: _loadMoreError,
                              onRetry: () {
                                if (!mounted || _currentUserId == null) return;
                                setState(() {
                                  _userPostsError = null;
                                  _isUserPostsLoading = true;
                                  _hasLoadedOnce = false;
                                });
                                context.read<UserPostsBloc>().add(
                                  RefreshUserPostsEvent(
                                    profileUserId: _currentUserId!,
                                    currentUserId: _currentUserId!,
                                  ),
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
