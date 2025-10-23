import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';

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
  bool _isUserPostsLoading = false;
  String? _userPostsError;
  bool? _isFollowing;
  bool _isProcessingFollow = false;

  @override
  void initState() {
    super.initState();
    // MainPage dispatches GetProfileDataEvent, StartProfileRealtimeEvent, and GetUserPostsEvent when tab selected.
    // Set own profile flags since this is always the current user's profile in the bottom nav.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isOwnProfile = true;
          _userId = widget.userId; // Same as current user ID
        });
        AppLogger.info('ProfilePage: Set as own profile, userId: $_userId');
      }
    });
  }

  @override
  void dispose() {
    // Note: Realtime stop is handled in Bloc or MainPage dispose; no per-page stop needed with IndexedStack.
    super.dispose();
  }

  void _handleRealtimePostUpdate(RealtimePostUpdate state) {
    final index = _userPosts.indexWhere((p) => p.id == state.postId);
    if (index != -1 && mounted) {
      final post = _userPosts[index];
      // Clamp to prevent negative counts from real-time updates
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
        followerId: _userId!,
        followingId: widget.userId,
        isFollowing: newFollowing,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(LogoutEvent());
                if (context.mounted) {
                  SnackbarUtils.showInfo(context, 'Logging out...');
                }
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
                    _showLogoutDialog(context);
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
      body: MultiBlocListener(
        listeners: [
          BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) {
              // Real-time updates are handled automatically via the stream
              // No manual actions needed here
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
                    _isUserPostsLoading = false;
                  });
                }
              } else if (state is UserPostsError) {
                if (mounted) {
                  setState(() {
                    _userPostsError = state.message;
                    _isUserPostsLoading = false;
                  });
                }
              } else if (state is PostLiked) {
                final index = _userPosts.indexWhere(
                  (p) => p.id == state.postId,
                );
                if (index != -1 && mounted) {
                  final delta = state.isLiked ? 1 : -1;
                  final newCount = (_userPosts[index].likesCount + delta)
                      .clamp(0, double.infinity)
                      .toInt();
                  final updatedPost = _userPosts[index].copyWith(
                    likesCount: newCount,
                    isLiked: state.isLiked,
                  );
                  setState(() => _userPosts[index] = updatedPost);
                }
              } else if (state is PostFavorited) {
                final index = _userPosts.indexWhere(
                  (p) => p.id == state.postId,
                );
                if (index != -1 && mounted) {
                  final delta = state.isFavorited ? 1 : -1;
                  final newCount = (_userPosts[index].favoritesCount + delta)
                      .clamp(0, double.infinity)
                      .toInt();
                  final updatedPost = _userPosts[index].copyWith(
                    favoritesCount: newCount,
                    isFavorited: state.isFavorited,
                  );
                  setState(() => _userPosts[index] = updatedPost);
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
                AppLogger.error('PostsError in ProfilePage: ${state.message}');
              }
            },
          ),
          BlocListener<FollowersBloc, FollowersState>(
            listener: (context, state) {
              if (state is FollowStatusLoaded &&
                  state.followingId == widget.userId) {
                if (mounted) {
                  setState(() => _isFollowing = state.isFollowing);
                }
              } else if (state is UserFollowed &&
                  state.followedUserId == widget.userId) {
                if (mounted) {
                  setState(() {
                    _isFollowing = state.isFollowing;
                    _isProcessingFollow = false;
                  });
                  // Profile counts will be updated automatically via real-time stream
                  AppLogger.info(
                    'Follow action completed. Profile counts will update via real-time stream.',
                  );
                }
              } else if (state is FollowersError) {
                if (mounted) {
                  if (_isProcessingFollow) {
                    setState(() {
                      _isFollowing = !_isFollowing!;
                      _isProcessingFollow = false;
                    });
                  }
                  SnackbarUtils.showError(context, state.message);
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
                onRetry: () {
                  context.read<ProfileBloc>().add(
                    GetProfileDataEvent(widget.userId),
                  );
                },
              );
            }
            if (state is ProfileDataLoaded) {
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<ProfileBloc>().add(
                    GetProfileDataEvent(widget.userId),
                  );
                  context.read<PostsBloc>().add(
                    GetUserPostsEvent(
                      profileUserId: widget.userId,
                      viewerUserId: _userId,
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      _userPosts.clear();
                      _userPostsError = null;
                    });
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      ProfileHeader(
                        profile: state.profile,
                        isOwnProfile: _isOwnProfile,
                        isFollowing: _isFollowing,
                        onFollowToggle: _onFollowToggle,
                        isProcessingFollow: _isProcessingFollow,
                      ),
                      ProfilePostsList(
                        posts: _userPosts,
                        userId: _userId ?? '',
                        isLoading: _isUserPostsLoading,
                        error: _userPostsError,
                        onRetry: () {
                          if (mounted) {
                            setState(() {
                              _userPostsError = null;
                              _isUserPostsLoading = true;
                            });
                          }

                          context.read<PostsBloc>().add(
                            GetUserPostsEvent(
                              profileUserId: widget.userId,
                              viewerUserId: _userId,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
