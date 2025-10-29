import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';

/// Standalone profile page for viewing other users' profiles
/// This page is NOT part of the bottom navigation bar
// lib/features/profile/presentation/pages/user_profile_page.dart
class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _currentUserId;
  bool _isOwnProfile = false;
  final List<PostEntity> _userPosts = [];
  bool _hasMoreUserPosts = true; // Added
  bool _isUserPostsLoading = false;
  bool _isLoadingMoreUserPosts = false; // Added
  String? _userPostsError;
  String? _loadMoreError; // Added
  bool? _isFollowing;
  bool _isProcessingFollow = false;
  final ScrollController _scrollController = ScrollController(); // Added
  static const Duration _loadMoreDebounce = Duration(
    milliseconds: 300,
  ); // Added

  @override
  void initState() {
    super.initState();
    _setupScrollListener(); // Added
    _loadCurrentUser();
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

  Future<void> _loadCurrentUser() async {
    try {
      final supabase = sl<SupabaseClient>();
      final sessionUserId = supabase.auth.currentUser?.id;
      if (sessionUserId == null) {
        AppLogger.error('No user session found in UserProfilePage');
        return;
      }
      if (mounted) {
        setState(() {
          _currentUserId = sessionUserId;
          _isOwnProfile = sessionUserId == widget.userId;
        });
        // Request profile + posts. Do NOT start/stop realtime here.
        context.read<ProfileBloc>().add(GetProfileDataEvent(widget.userId));
        context.read<PostsBloc>().add(
          GetUserPostsEvent(
            profileUserId: widget.userId,
            currentUserId: sessionUserId,
          ),
        );
        if (!_isOwnProfile) {
          context.read<FollowersBloc>().add(
            GetFollowStatusEvent(
              followerId: sessionUserId,
              followingId: widget.userId,
            ),
          );
        }
        AppLogger.info(
          'UserProfilePage: Initialized for userId: ${widget.userId}, currentUser: $sessionUserId',
        );
        // NEW: Subscribe to real-time for this profile if not own
        if (!_isOwnProfile) {
          final realtime = sl<RealtimeService>();
          await realtime.subscribeToProfile(widget.userId);
        }
      }
    } catch (e, st) {
      AppLogger.error(
        'Error loading current user in UserProfilePage: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void dispose() {
    // No explicit StopProfileRealtimeEvent here — centralized RealtimeService handles lifecycle.
    // NEW: Unsubscribe if not own profile
    if (!_isOwnProfile) {
      final realtime = sl<RealtimeService>();
      realtime.unsubscribeFromProfile(widget.userId);
    }
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
    if (_isProcessingFollow || _currentUserId == null) return;
    setState(() {
      _isProcessingFollow = true;
      _isFollowing = newFollowing;
    });
    context.read<FollowersBloc>().add(
      FollowUserEvent(
        followerId: _currentUserId!,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) {
              if (state is ProfileDataLoaded)
                AppLogger.info(
                  'User profile updated via real-time stream: ${state.profile.username}',
                );
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
              } else if (state is UserPostsError) {
                if (mounted)
                  setState(() {
                    _userPostsError = state.message;
                    _isUserPostsLoading = false;
                  });
              } else if (state is UserPostsLoadMoreError) {
                if (mounted) {
                  setState(() {
                    _loadMoreError = state.message;
                    _isLoadingMoreUserPosts = false;
                  });
                }
              } else if (state is RealtimePostUpdate)
                _handleRealtimePostUpdate(state);
              else if (state is PostDeleted) {
                final index = _userPosts.indexWhere(
                  (p) => p.id == state.postId,
                );
                if (index != -1 && mounted)
                  setState(() => _userPosts.removeAt(index));
              }
            },
          ),
          BlocListener<LikesBloc, LikesState>(
            listener: (context, state) {
              if (state is LikeUpdated)
                _applyLikeUpdate(state.postId, state.isLiked);
              else if (state is LikeError) {
                _revertLike(state.postId, state.previousState);
                SnackbarUtils.showError(context, state.message);
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoriteUpdated)
                _applyFavoriteUpdate(state.postId, state.isFavorited);
              else if (state is FavoriteError) {
                _revertFavorite(state.postId, state.previousState);
                SnackbarUtils.showError(context, state.message);
              }
            },
          ),
          BlocListener<FollowersBloc, FollowersState>(
            listener: (context, state) {
              if (state is FollowStatusLoaded &&
                  state.followingId == widget.userId) {
                if (mounted) setState(() => _isFollowing = state.isFollowing);
              } else if (state is UserFollowed &&
                  state.followedUserId == widget.userId) {
                if (mounted)
                  setState(() {
                    _isFollowing = state.isFollowing;
                    _isProcessingFollow = false;
                  });
                // REMOVE: The post-UserFollowed refresh, as real-time sub will now handle the followers_count update automatically.
              } else if (state is FollowersError) {
                if (mounted) {
                  if (_isProcessingFollow && _isFollowing != null)
                    setState(() {
                      _isFollowing = !_isFollowing!;
                      _isProcessingFollow = false;
                    });
                  SnackbarUtils.showError(context, state.message);
                }
              }
            },
          ),
        ],
        child: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading || state is ProfileInitial)
              return const Center(child: LoadingIndicator());
            if (state is ProfileError)
              return CustomErrorWidget(
                message: state.message,
                onRetry: () => context.read<ProfileBloc>().add(
                  GetProfileDataEvent(widget.userId),
                ),
              );
            if (state is ProfileDataLoaded) {
              return RefreshIndicator(
                onRefresh: () async {
                  if (_currentUserId != null) {
                    context.read<PostsBloc>().add(
                      RefreshUserPostsEvent(
                        profileUserId: widget.userId,
                        currentUserId: _currentUserId!,
                      ),
                    );
                    if (mounted)
                      setState(() {
                        _userPosts.clear();
                        _userPostsError = null;
                        _hasMoreUserPosts = true;
                      });
                  }
                },
                child: CustomScrollView(
                  // Changed to CustomScrollView
                  controller: _scrollController, // Added
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: ProfileHeader(
                        profile: state.profile,
                        isOwnProfile: _isOwnProfile,
                        // ✅ CHANGED: Pass state variables and the toggle function
                        isFollowing: _isFollowing,
                        onFollowToggle: _onFollowToggle,
                        isProcessingFollow: _isProcessingFollow,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ProfilePostsList(
                        posts: _userPosts,
                        userId: _currentUserId ?? '',
                        isLoading: _isUserPostsLoading,
                        error: _userPostsError,
                        hasMore: _hasMoreUserPosts, // Added
                        isLoadingMore: _isLoadingMoreUserPosts, // Added
                        loadMoreError: _loadMoreError, // Added
                        onRetry: () {
                          if (mounted && _currentUserId != null) {
                            setState(() {
                              _userPostsError = null;
                              _isUserPostsLoading = true;
                            });
                            context.read<PostsBloc>().add(
                              GetUserPostsEvent(
                                profileUserId: widget.userId,
                                currentUserId: _currentUserId!,
                              ),
                            );
                          }
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
    );
  }
}
