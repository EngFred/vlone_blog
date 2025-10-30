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
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';

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
    // 💡 FIX IMPLEMENTED HERE: Ensure UI is showing loading state immediately
    // If the list is empty, we must be loading or show an error/empty state.
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

    // 💡 FIX: Changed to RefreshUserPostsEvent to reset pagination
    context.read<PostsBloc>().add(
      RefreshUserPostsEvent(
        // <-- WAS: GetUserPostsEvent
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
              context.read<PostsBloc>().add(LoadMoreUserPostsEvent());
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

  void _handleRealtimePostUpdate(RealtimePostUpdate state) {
    final index = _userPosts.indexWhere((p) => p.id == state.postId);
    if (index != -1 && mounted) {
      final post = _userPosts[index];
      final updatedPost = post.copyWith(
        likesCount: (state.likesCount ?? post.likesCount)
            .clamp(0, double.infinity)
            .toInt(),
        commentsCount: (state.commentsCount ?? post.commentsCount)
            .clamp(0, double.infinity)
            .toInt(),
        favoritesCount: (state.favoritesCount ?? post.favoritesCount)
            .clamp(0, double.infinity)
            .toInt(),
        sharesCount: (state.sharesCount ?? post.sharesCount)
            .clamp(0, double.infinity)
            .toInt(),
      );
      setState(() => _userPosts[index] = updatedPost);
    }
  }

  void _applyLikeUpdate(String postId, bool isLiked) {
    final index = _userPosts.indexWhere((p) => p.id == postId);
    if (index == -1 || !mounted) {
      return;
    }
    final old = _userPosts[index];
    final delta = isLiked ? 1 : -1;
    final updated = old.copyWith(
      likesCount: (old.likesCount + delta).clamp(0, double.infinity).toInt(),
      isLiked: isLiked,
    );
    setState(() => _userPosts[index] = updated);
  }

  void _revertLike(String postId, bool previousState) {
    final index = _userPosts.indexWhere((p) => p.id == postId);
    if (index == -1 || !mounted) {
      return;
    }
    final old = _userPosts[index];
    final correctedCount = previousState
        ? (old.likesCount + 1)
        : (old.likesCount - 1);
    setState(
      () => _userPosts[index] = old.copyWith(
        isLiked: previousState,
        likesCount: correctedCount.clamp(0, double.infinity).toInt(),
      ),
    );
  }

  void _applyFavoriteUpdate(String postId, bool isFavorited) {
    final index = _userPosts.indexWhere((p) => p.id == postId);
    if (index == -1 || !mounted) {
      return;
    }
    final old = _userPosts[index];
    final delta = isFavorited ? 1 : -1;
    final updated = old.copyWith(
      favoritesCount: (old.favoritesCount + delta)
          .clamp(0, double.infinity)
          .toInt(),
      isFavorited: isFavorited,
    );
    setState(() => _userPosts[index] = updated);
  }

  void _revertFavorite(String postId, bool previousState) {
    final index = _userPosts.indexWhere((p) => p.id == postId);
    if (index == -1 || !mounted) {
      return;
    }
    final old = _userPosts[index];
    final correctedCount = previousState
        ? (old.favoritesCount + 1)
        : (old.favoritesCount - 1);
    setState(
      () => _userPosts[index] = old.copyWith(
        isFavorited: previousState,
        favoritesCount: correctedCount.clamp(0, double.infinity).toInt(),
      ),
    );
  }

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
                  BlocListener<PostsBloc, PostsState>(
                    listener: (context, state) {
                      if (state is UserPostsLoaded) {
                        // Check for foreign user state before updating local state
                        if (state.profileUserId != null &&
                            state.profileUserId != _currentUserId) {
                          AppLogger.info(
                            'ProfilePage: PostsBloc state is for foreign profile (${state.profileUserId}). Triggering refresh for $_currentUserId.',
                          );
                          context.read<PostsBloc>().add(
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
                            // Clear only if this is not a load-more, but since UserPostsLoaded
                            // represents the *entire* current list from the BLoC, we clear and add.
                            _userPosts.clear();
                            _userPostsError = null;
                            _userPosts.addAll(
                              state.posts.map(
                                (p) => p.copyWith(
                                  likesCount: p.likesCount
                                      .clamp(0, double.infinity)
                                      .toInt(),
                                  commentsCount: p.commentsCount
                                      .clamp(0, double.infinity)
                                      .toInt(),
                                  favoritesCount: p.favoritesCount
                                      .clamp(0, double.infinity)
                                      .toInt(),
                                  sharesCount: p.sharesCount
                                      .clamp(0, double.infinity)
                                      .toInt(),
                                ),
                              ),
                            );
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
                      } else if (state is PostCreated) {
                        if (mounted) {
                          // Only add if the post was created by the current user
                          if (state.post.userId == _currentUserId) {
                            final exists = _userPosts.any(
                              (p) => p.id == state.post.id,
                            );
                            if (!exists) {
                              setState(() => _userPosts.insert(0, state.post));
                            }
                          }
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
                          // This state should set loading, but we already set it in _initializeProfile
                          // to handle the initial load race condition. We keep this to catch subsequent loading states.
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
                      } else if (state is RealtimePostUpdate) {
                        _handleRealtimePostUpdate(state);
                      } else if (state is PostDeleted) {
                        final index = _userPosts.indexWhere(
                          (p) => p.id == state.postId,
                        );
                        if (index != -1 && mounted) {
                          setState(() => _userPosts.removeAt(index));
                        }
                      } else if (state is PostsError) {
                        AppLogger.error(
                          'PostsError in ProfilePage: ${state.message}',
                        );
                      }
                    },
                  ),
                  BlocListener<LikesBloc, LikesState>(
                    listener: (context, state) {
                      if (state is LikeUpdated) {
                        _applyLikeUpdate(state.postId, state.isLiked);
                      } else if (state is LikeError) {
                        _revertLike(state.postId, state.previousState);
                      }
                    },
                  ),
                  BlocListener<FavoritesBloc, FavoritesState>(
                    listener: (context, state) {
                      if (state is FavoriteUpdated) {
                        _applyFavoriteUpdate(state.postId, state.isFavorited);
                      } else if (state is FavoriteError) {
                        _revertFavorite(state.postId, state.previousState);
                      }
                    },
                  ),
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
                          context.read<PostsBloc>().add(
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
                                  context.read<PostsBloc>().add(
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
