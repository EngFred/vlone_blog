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
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';

enum ProfileMenuOption { edit, logout }

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isOwnProfile = false;
  String? _userId;
  final List<PostEntity> _userPosts = [];
  bool _hasMoreUserPosts = true; // Added: Track hasMore
  bool _isUserPostsLoading = false;
  bool _isLoadingMoreUserPosts = false; // Added: For load more state
  String? _userPostsError;
  String? _loadMoreError; // Added: For load more errors
  bool? _isFollowing;
  bool _isProcessingFollow = false;
  String? _loadedProfileUserId;
  final ScrollController _scrollController =
      ScrollController(); // Added: For pagination
  static const Duration _loadMoreDebounce = Duration(
    milliseconds: 300,
  ); // Added: Debounce

  @override
  void initState() {
    super.initState();
    _setupScrollListener(); // Added: Setup listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeProfile();
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        Debouncer.instance.debounce(
          'load_more_user_posts',
          _loadMoreDebounce,
          () {
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

  void _initializeProfile() {
    setState(() {
      _isOwnProfile = true;
      _userId = widget.userId;
    });
    if (_loadedProfileUserId != widget.userId) {
      _loadedProfileUserId = widget.userId;
      _userPosts.clear();
      _userPostsError = null;
      _loadMoreError = null;
      _isUserPostsLoading = false;
      _hasMoreUserPosts = true;
      // ✅ OPTIMIZATION: Removed eager data fetches.
      // MainPage's _dispatchLoadForIndex(3) is now responsible for
      // dispatching GetProfileDataEvent and GetUserPostsEvent.
      // We still run the rest of this method to clear old state.
      AppLogger.info('ProfilePage: Initialized for userId: ${widget.userId}');
    }
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      AppLogger.info(
        'ProfilePage userId changed from ${oldWidget.userId} to ${widget.userId}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initializeProfile();
      });
    }
  }

  @override
  void dispose() {
    // Do NOT stop realtime here: the centralized RealtimeService is managed at app-level.
    _scrollController.dispose(); // Added
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

  void _onFollowToggle(bool newFollowing) {
    if (_isProcessingFollow) return;
    setState(() {
      _isProcessingFollow = true;
      _isFollowing = newFollowing;
    });
    context.read<FollowersBloc>().add(
      FollowUserEvent(
        followerId: _userId ?? '',
        followingId: widget.userId,
        isFollowing: newFollowing,
      ),
    );
  }

  void _applyLikeUpdate(String postId, bool isLiked) {
    final index = _userPosts.indexWhere((p) => p.id == postId);
    if (index == -1 || !mounted) return;
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
    if (index == -1 || !mounted) return;
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
    if (index == -1 || !mounted) return;
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
    if (index == -1 || !mounted) return;
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

  // --- Extracted Logout Confirmation Dialog ---
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
              Icon(Icons.warning, color: Colors.orange),
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
                // 1. Close the dialog
                Navigator.of(dialogContext).pop();
                // 2. Dispatch the logout event (AuthBloc state will transition to AuthLoading)
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
  // --- End Extracted Logout Confirmation Dialog ---

  @override
  Widget build(BuildContext context) {
    // Use BlocConsumer to handle both error state feedback and rebuild for the loading overlay.
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          // If logout fails, show an error message
          SnackbarUtils.showError(context, state.message);
        }
      },
      builder: (context, authState) {
        // Determine if we are currently logging out
        final isLoggingOut = authState is AuthLoading;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            centerTitle: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            actions: [
              if (_isOwnProfile)
                PopupMenuButton<ProfileMenuOption>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case ProfileMenuOption.edit:
                        context.push(
                          '${Constants.profileRoute}/${widget.userId}/edit',
                        );
                        break;
                      case ProfileMenuOption.logout:
                        _showLogoutConfirmationDialog();
                        break;
                    }
                  },
                  itemBuilder: (menuContext) {
                    final iconColor = Theme.of(
                      menuContext,
                    ).colorScheme.onSurface;
                    final textStyle = Theme.of(
                      menuContext,
                    ).textTheme.bodyMedium;
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
              // 1. Main Profile Content (wrapped in MultiBlocListener/BlocBuilder)
              MultiBlocListener(
                listeners: [
                  BlocListener<ProfileBloc, ProfileState>(
                    listener: (context, state) {
                      if (state is ProfileDataLoaded) {
                        AppLogger.info(
                          'Profile updated via real-time stream: ${state.profile.username}',
                        );
                      }
                    },
                  ),
                  BlocListener<PostsBloc, PostsState>(
                    listener: (context, state) {
                      if (state is UserPostsLoading) {
                        if (mounted) setState(() => _isUserPostsLoading = true);
                      } else if (state is UserPostsLoaded) {
                        if (mounted) {
                          setState(() {
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
                            _hasMoreUserPosts = state.hasMore; // Added
                            _isUserPostsLoading = false;
                            _isLoadingMoreUserPosts = false; // Added
                            _loadMoreError = null; // Added
                          });
                        }
                      } else if (state is PostCreated) {
                        if (_isOwnProfile && mounted) {
                          final exists = _userPosts.any(
                            (p) => p.id == state.post.id,
                          );
                          if (!exists)
                            setState(() => _userPosts.insert(0, state.post));
                        }
                      } else if (state is UserPostsError) {
                        if (mounted) {
                          setState(() {
                            _userPostsError = state.message;
                            _isUserPostsLoading = false;
                          });
                        }
                      } else if (state is UserPostsLoadingMore) {
                        // Optional
                      } else if (state is UserPostsLoadMoreError) {
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
                  BlocListener<FollowersBloc, FollowersState>(
                    listener: (context, state) {
                      if (state is FollowStatusLoaded &&
                          state.followingId == widget.userId) {
                        if (mounted)
                          setState(() => _isFollowing = state.isFollowing);
                      } else if (state is UserFollowed &&
                          state.followedUserId == widget.userId) {
                        if (mounted) {
                          setState(() {
                            _isFollowing = state.isFollowing;
                            _isProcessingFollow = false;
                          });
                        }
                      } else if (state is FollowersError) {
                        if (mounted) {
                          if (_isProcessingFollow && _isFollowing != null) {
                            setState(() {
                              _isFollowing = !_isFollowing!;
                              _isProcessingFollow = false;
                            });
                          }
                        }
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
                          GetProfileDataEvent(widget.userId),
                        ),
                      );
                    }
                    if (state is ProfileDataLoaded) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<PostsBloc>().add(
                            RefreshUserPostsEvent(
                              // Changed to Refresh for reset pagination
                              profileUserId: widget.userId,
                              currentUserId: _userId ?? '',
                            ),
                          );
                          if (mounted) {
                            setState(() {
                              _userPosts.clear();
                              _userPostsError = null;
                              _hasMoreUserPosts = true;
                            });
                          }
                        },
                        child: CustomScrollView(
                          // Changed: To CustomScrollView for better pagination
                          controller: _scrollController, // Added
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: ProfileHeader(
                                profile: state.profile,
                                isOwnProfile: _isOwnProfile,
                                isFollowing: _isFollowing,
                                onFollowToggle: _onFollowToggle,
                                isProcessingFollow: _isProcessingFollow,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: ProfilePostsList(
                                posts: _userPosts,
                                userId: _userId ?? '',
                                isLoading: _isUserPostsLoading,
                                error: _userPostsError,
                                hasMore: _hasMoreUserPosts, // Added
                                isLoadingMore: _isLoadingMoreUserPosts, // Added
                                loadMoreError: _loadMoreError, // Added
                                onRetry: () {
                                  if (mounted)
                                    setState(() {
                                      _userPostsError = null;
                                      _isUserPostsLoading = true;
                                    });
                                  context.read<PostsBloc>().add(
                                    GetUserPostsEvent(
                                      profileUserId: widget.userId,
                                      currentUserId: _userId ?? '',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              // 2. Loading Overlay (Appears only when isLoggingOut is true)
              if (isLoggingOut)
                const SavingLoadingOverlay(message: 'Logging out...'),
            ],
          ),
        );
      },
    );
  }
}
