import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';

/// Standalone profile page for viewing other users' profiles
/// This page is NOT part of the bottom navigation bar
class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _currentUserId;
  bool _isOwnProfile = false;
  bool _isLoadingMoreUserPosts = false;

  bool? _isFollowing;
  bool _isProcessingFollow = false;
  final ScrollController _scrollController = ScrollController();
  static const Duration _loadMoreDebounce = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    _loadCurrentUser();
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

        // Check if posts have been loaded at least once by checking the state type
        final bool hasLoadedOnce =
            userPostsState is UserPostsLoaded ||
            userPostsState is UserPostsLoadingMore ||
            userPostsState is UserPostsLoadMoreError;

        // The local flag _isLoadingMoreUserPosts is still needed to debounce the BLoC dispatch
        // while the BLoC is transitioning to a LoadingMore or Loaded state.
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

        // Request profile data (uses local ProfileBloc instance)
        context.read<ProfileBloc>().add(GetProfileDataEvent(widget.userId));

        // Start realtime listener on the local ProfileBloc instance
        if (!_isOwnProfile) {
          context.read<ProfileBloc>().add(
            StartProfileRealtimeEvent(widget.userId),
          );
        }

        // Request user posts (uses local UserPostsBloc instance)
        context.read<UserPostsBloc>().add(
          RefreshUserPostsEvent(
            profileUserId: widget.userId,
            currentUserId: _currentUserId!,
          ),
        );

        // Start UserPosts real-time if not own profile
        if (!_isOwnProfile) {
          context.read<UserPostsBloc>().add(
            StartUserPostsRealtime(profileUserId: widget.userId),
          );
        }

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

        // Subscribe to general real-time for this profile if not own
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
    // Unsubscribe if not own profile
    if (!_isOwnProfile) {
      final realtime = sl<RealtimeService>();
      realtime.unsubscribeFromProfile(widget.userId);
    }

    // Stop realtime listener on the local ProfileBloc instance (cancels sub in bloc.close())
    if (!_isOwnProfile) {
      context.read<ProfileBloc>().add(const StopProfileRealtimeEvent());
      context.read<UserPostsBloc>().add(const StopUserPostsRealtime());
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onFollowToggle(bool newFollowing) {
    if (_isProcessingFollow || _currentUserId == null) {
      return;
    }
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

  // New method to handle the RefreshIndicator logic
  Future<void> _onRefreshProfile() async {
    if (_currentUserId == null) return;

    // 1. Refresh profile data
    context.read<ProfileBloc>().add(GetProfileDataEvent(widget.userId));

    // 2. Refresh posts
    context.read<UserPostsBloc>().add(
      RefreshUserPostsEvent(
        profileUserId: widget.userId,
        currentUserId: _currentUserId!,
      ),
    );

    // 3. Reset local loading flags for scroll listener
    if (mounted) {
      setState(() {
        _isLoadingMoreUserPosts = false;
        // _hasLoadedOnce is implicitly reset by the BLoC transition to UserPostsLoading/Loaded
        // but we rely on the BLoC state itself now, not a local guard.
      });
    }
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
              if (state is ProfileDataLoaded) {
                AppLogger.info(
                  'User profile loaded/updated: ${state.profile.username}',
                );
              }
            },
          ),
          // Listen to UserPostsBloc for loading more status
          BlocListener<UserPostsBloc, UserPostsState>(
            listener: (context, state) {
              if (!mounted || state.profileUserId != widget.userId) return;

              // This listener primarily manages the local flag for scroll debounce
              if (state is UserPostsLoaded || state is UserPostsLoadMoreError) {
                if (_isLoadingMoreUserPosts) {
                  setState(() => _isLoadingMoreUserPosts = false);
                }
              }
              // The main list/error state is handled by the BlocBuilder below.
            },
          ),
          // Listener for PostActionsBloc to handle post deletion
          BlocListener<PostActionsBloc, PostActionsState>(
            listenWhen: (previous, current) => current is PostDeletedSuccess,
            listener: (context, state) {
              if (state is PostDeletedSuccess) {
                // Delegate removal to UserPostsBloc for clean state management
                context.read<UserPostsBloc>().add(
                  RemovePostFromUserPosts(state.postId),
                );
              }
            },
          ),
          BlocListener<FollowersBloc, FollowersState>(
            listener: (context, state) {
              if (state is FollowStatusLoaded &&
                  state.followingId == widget.userId) {
                if (mounted) {
                  setState(() {
                    _isFollowing = state.isFollowing;
                  });
                }
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
                    // Revert UI state if the action failed
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
          builder: (context, profileState) {
            if (profileState is ProfileLoading ||
                profileState is ProfileInitial) {
              return const Center(child: LoadingIndicator());
            }
            if (profileState is ProfileError) {
              return CustomErrorWidget(
                message: profileState.message,
                onRetry: () => context.read<ProfileBloc>().add(
                  GetProfileDataEvent(widget.userId),
                ),
              );
            }
            if (profileState is ProfileDataLoaded) {
              // Check if wrong user and reload (safety check)
              if (profileState.userId != widget.userId) {
                context.read<ProfileBloc>().add(
                  GetProfileDataEvent(widget.userId),
                );
                return const Center(child: LoadingIndicator());
              }

              final bottomPadding = MediaQuery.of(context).padding.bottom;

              return SafeArea(
                top: false,
                bottom: true,
                child: RefreshIndicator(
                  onRefresh: _onRefreshProfile,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: ProfileHeader(
                          profile: profileState.profile,
                          isOwnProfile: _isOwnProfile,
                          isFollowing: _isFollowing,
                          onFollowToggle: _onFollowToggle,
                          isProcessingFollow: _isProcessingFollow,
                        ),
                      ),
                      // --- NESTED BLOCBUILDER FOR USER POSTS STATE ---
                      BlocBuilder<UserPostsBloc, UserPostsState>(
                        builder: (context, userPostsState) {
                          // Filter state relevance to this profile
                          if (userPostsState.profileUserId != widget.userId) {
                            return const SliverToBoxAdapter(
                              child: SizedBox.shrink(),
                            );
                          }

                          // Extract data directly from BLoC state
                          List<PostEntity> posts = [];
                          bool isLoading = false;
                          String? error;
                          bool hasMore = false;
                          String? loadMoreError;

                          if (userPostsState is UserPostsLoading) {
                            isLoading = true;
                          } else if (userPostsState is UserPostsError) {
                            error = userPostsState.message;
                          } else if (userPostsState is UserPostsLoaded) {
                            posts = userPostsState.posts;
                            hasMore = userPostsState.hasMore;
                          } else if (userPostsState is UserPostsLoadingMore) {
                            posts = userPostsState.posts;
                            hasMore = true; // Still expecting more data
                          } else if (userPostsState is UserPostsLoadMoreError) {
                            posts = userPostsState.posts;
                            loadMoreError = userPostsState.message;
                            hasMore = true; // Show retry button
                          }

                          return SliverPadding(
                            padding: EdgeInsets.only(
                              bottom: bottomPadding + 16.0,
                            ),
                            sliver: ProfilePostsList(
                              posts: posts,
                              userId: _currentUserId ?? '',
                              isLoading: isLoading,
                              error: error,
                              hasMore: hasMore,
                              isLoadingMore:
                                  _isLoadingMoreUserPosts &&
                                  userPostsState is UserPostsLoadingMore,
                              loadMoreError: loadMoreError,
                              onRetry: () {
                                if (!mounted || _currentUserId == null) return;
                                // FIXED: Use Refresh for reset (vs. Get)
                                context.read<UserPostsBloc>().add(
                                  RefreshUserPostsEvent(
                                    profileUserId: widget.userId,
                                    currentUserId: _currentUserId!,
                                  ),
                                );
                              },
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
