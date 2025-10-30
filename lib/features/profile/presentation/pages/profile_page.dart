import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/widgets/loading_overlay.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';

enum ProfileMenuOption { edit, logout }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _currentUserId;
  final List<PostEntity> _userPosts = [];
  bool _hasMoreUserPosts = true;
  // Initialize to true for the *first* load to ensure loading indicator is shown
  bool _isUserPostsLoading = true;
  bool _isLoadingMoreUserPosts = false;
  String? _userPostsError;
  String? _loadMoreError;
  final ScrollController _scrollController = ScrollController();
  static const Duration _loadMoreDebounce = Duration(milliseconds: 300);

  // NEW: guard to prevent triggering load-more before initial load completes
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    // 1. Get the ID once in initState.
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.id;
    } else {
      _currentUserId = null;
    }
    // 2. Guarantee initialization after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeProfile();
      }
    });
  }

  // Simplified and renamed to reflect single purpose
  void _initializeProfile() {
    if (_currentUserId == null) {
      AppLogger.error(
        'ProfilePage: User is not authenticated. Cannot initialize.',
      );
      return; // Early exit if no user ID
    }

    // 💡 Update local state for immediate loading feedback
    if (_userPosts.isEmpty && _isUserPostsLoading == false) {
      setState(() {
        _isUserPostsLoading = true;
      });
    }

    // Clear local lists for a fresh load (posts are rebuilt from BLoC state)
    _userPosts.clear();
    _userPostsError = null;
    _loadMoreError = null;
    _hasMoreUserPosts = true;
    _hasLoadedOnce = false; // reset guard for fresh load

    // Dispatch events to load data for the current user's ID
    context.read<ProfileBloc>().add(GetProfileDataEvent(_currentUserId!));

    //Dispatch to UserPostsBloc
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

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        Debouncer.instance.debounce(
          'load_more_user_posts',
          _loadMoreDebounce,
          () {
            // NEW: do not attempt load-more until initial load completed
            if (!_hasLoadedOnce) return;
            if (_scrollController.position.pixels >=
                    _scrollController.position.maxScrollExtent - 200 &&
                _hasMoreUserPosts &&
                !_isLoadingMoreUserPosts) {
              setState(() => _isLoadingMoreUserPosts = true);
              // ✅ CHANGE: Dispatch to UserPostsBloc
              context.read<UserPostsBloc>().add(LoadMoreUserPostsEvent());
            }
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ❌ REMOVED: _handleRealtimePostUpdate (The BLoC should handle this)
  // ❌ REMOVED: _applyLikeUpdate (The PostActionsBloc update should be sufficient)
  // ❌ REMOVED: _revertLike (The PostActionsBloc update should be sufficient)
  // ❌ REMOVED: _applyFavoriteUpdate (The PostActionsBloc update should be sufficient)
  // ❌ REMOVED: _revertFavorite (The PostActionsBloc update should be sufficient)

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Logout Confirmation'),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out? You will need to sign in again to access your account.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(LogoutEvent());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      AppLogger.error('ProfilePage: Rendering Error - Unauthenticated User');
      return const Center(child: Text('Error: User not logged in.'));
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
          appBar: AppBar(
            title: const Text('My Profile'),
            centerTitle: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            actions: [
              PopupMenuButton<ProfileMenuOption>(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onSelected: (value) {
                  switch (value) {
                    case ProfileMenuOption.edit:
                      context.push(
                        '${Constants.profileRoute}/$_currentUserId/edit',
                      );
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
                          Icon(Icons.edit, color: iconColor),
                          const SizedBox(width: 8),
                          Text('Edit Profile', style: textStyle),
                        ],
                      ),
                    ),
                    PopupMenuItem<ProfileMenuOption>(
                      value: ProfileMenuOption.logout,
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: iconColor),
                          const SizedBox(width: 8),
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
                        // FIX: Refresh posts if the loaded profile ID is NOT the current user's ID.
                        if (state.userId != _currentUserId) {
                          AppLogger.info(
                            'ProfilePage: ProfileBloc updated to foreign user (${state.userId}). Re-initializing.',
                          );
                          _initializeProfile();
                        } else {
                          AppLogger.info(
                            'Profile updated via real-time stream: ${state.profile.username}',
                          );
                        }
                      }
                    },
                  ),

                  // ✅ CHANGE: Listen to UserPostsBloc
                  BlocListener<UserPostsBloc, UserPostsState>(
                    listener: (context, state) {
                      if (state is UserPostsLoaded) {
                        // Check for foreign user state before updating local state
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
                          return; // Stop processing this event.
                        }
                        // Normal load/update logic for the correct user:
                        if (mounted) {
                          setState(() {
                            _userPosts.clear();
                            _userPostsError = null;
                            _userPosts.addAll(state.posts);
                            _hasMoreUserPosts = state.hasMore;
                            _isUserPostsLoading = false; // FINISHED LOADING
                            _isLoadingMoreUserPosts = false;
                            _loadMoreError = null;
                            _hasLoadedOnce =
                                true; // NEW: initial load completed
                          });
                          AppLogger.info(
                            'ProfilePage: Loaded ${_userPosts.length} posts for $_currentUserId',
                          );
                        }
                      } else if (state is UserPostsError) {
                        if (state.profileUserId != null &&
                            state.profileUserId != _currentUserId) {
                          return; // Ignore foreign user errors
                        }
                        if (mounted) {
                          setState(() {
                            _userPostsError = state.message;
                            _isUserPostsLoading = false;
                            _isLoadingMoreUserPosts = false;
                          });
                        }
                      } else if (state is UserPostsLoading) {
                        if (state.profileUserId != null &&
                            state.profileUserId != _currentUserId) {
                          return; // Ignore foreign user loading
                        }
                        if (mounted) {
                          setState(() => _isUserPostsLoading = true);
                        }
                      } else if (state is UserPostsLoadMoreError) {
                        if (state.profileUserId != null &&
                            state.profileUserId != _currentUserId)
                          return; // Ignore foreign user errors
                        if (mounted) {
                          setState(() {
                            _loadMoreError = state.message;
                            _isLoadingMoreUserPosts = false;
                          });
                        }
                      }
                      // ❌ REMOVED: RealtimePostUpdate listener (The BLoC should handle this)
                      // ❌ REMOVED: PostCreated listener (The PostActionsBloc/UserPostsBloc should coordinate this)
                      // ❌ REMOVED: PostDeleted listener (The PostActionsBloc/UserPostsBloc should coordinate this)
                    },
                  ),

                  // ✅ ADDED: Listener for PostActionsBloc to handle post creation/deletion
                  BlocListener<PostActionsBloc, PostActionsState>(
                    listenWhen: (previous, current) =>
                        current is PostCreatedSuccess ||
                        current is PostDeletedSuccess,
                    listener: (context, state) {
                      if (state is PostCreatedSuccess) {
                        // Only add if created by the current user
                        if (state.post.userId == _currentUserId) {
                          final exists = _userPosts.any(
                            (p) => p.id == state.post.id,
                          );
                          if (!exists && mounted) {
                            setState(() => _userPosts.insert(0, state.post));
                          }
                        }
                      } else if (state is PostDeletedSuccess) {
                        // Delegate removal to UserPostsBloc for clean state management
                        context.read<UserPostsBloc>().add(
                          RemovePostFromUserPosts(state.postId),
                        );
                        // The UserPostsBloc's state update will remove it from the list.
                      }
                      // NOTE: We don't need to listen to PostOptimisticallyUpdated here
                      // because PostCard (the item widget) handles its own optimistic updates.
                    },
                  ),

                  // 💡 NOTE: We no longer need the detailed LikesBloc/FavoritesBloc listeners
                  // because we removed the manual local list mutation (`_applyLikeUpdate`, etc.).
                  // The `PostCard` widget now relies solely on its own inner optimistic update
                  // mechanism (listening to PostActionsBloc) and the data passed in its constructor
                  // (which should be eventually refreshed from the list BLoC).
                ],
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    if (state is ProfileLoading || state is ProfileInitial) {
                      return const Center(child: LoadingIndicator());
                    }
                    if (state is ProfileError) {
                      return CustomErrorWidget(
                        message: state.message,
                        onRetry: () => context.read<ProfileBloc>().add(
                          GetProfileDataEvent(_currentUserId!),
                        ),
                      );
                    }
                    if (state is ProfileDataLoaded) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<UserPostsBloc>().add(
                            RefreshUserPostsEvent(
                              profileUserId: _currentUserId!,
                              currentUserId: _currentUserId!,
                            ),
                          );
                          if (mounted) {
                            // Set local state variables for immediate UI feedback
                            setState(() {
                              _userPosts.clear();
                              _userPostsError = null;
                              _hasMoreUserPosts = true;
                              _isUserPostsLoading = true;
                              _hasLoadedOnce =
                                  false; // reset guard for manual refresh
                            });
                          }
                        },
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
                                if (mounted && _currentUserId != null) {
                                  setState(() {
                                    _userPostsError = null;
                                    _isUserPostsLoading = true;
                                    _hasLoadedOnce = false;
                                  });
                                  context.read<UserPostsBloc>().add(
                                    // Use RefreshUserPostsEvent on retry as well
                                    RefreshUserPostsEvent(
                                      profileUserId: _currentUserId!,
                                      currentUserId: _currentUserId!,
                                    ),
                                  );
                                }
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
