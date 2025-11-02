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
  // Local list remains to hold and display the posts fetched by UserPostsBloc
  final List<PostEntity> _userPosts = [];
  bool _hasMoreUserPosts = true;
  bool _isUserPostsLoading = false;
  bool _isLoadingMoreUserPosts = false;
  String? _userPostsError;
  String? _loadMoreError;
  bool? _isFollowing;
  bool _isProcessingFollow = false;
  final ScrollController _scrollController = ScrollController();
  static const Duration _loadMoreDebounce = Duration(milliseconds: 300);

  //guard to prevent triggering load-more before initial load completes
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    _loadCurrentUser();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        Debouncer.instance.debounce(
          'load_more_user_posts',
          _loadMoreDebounce,
          () {
            // NEW: don't load more until initial load completed
            if (!_hasLoadedOnce) return;
            if (_scrollController.position.pixels >=
                    _scrollController.position.maxScrollExtent - 200 &&
                _hasMoreUserPosts &&
                !_isLoadingMoreUserPosts) {
              setState(() {
                _isLoadingMoreUserPosts = true;
              });
              context.read<UserPostsBloc>().add(LoadMoreUserPostsEvent());
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
        // Request profile data (uses local ProfileBloc instance)
        context.read<ProfileBloc>().add(GetProfileDataEvent(widget.userId));

        // Start realtime listener on the local ProfileBloc instance
        // Only for non-own profiles to avoid overlap with MainPage's global bloc
        if (!_isOwnProfile) {
          context.read<ProfileBloc>().add(
            StartProfileRealtimeEvent(widget.userId),
          );
        }

        // Request user posts (uses local UserPostsBloc instance)
        // Ensure _currentUserId is set before dispatch
        // Use RefreshUserPostsEvent to be consistent and reset pagination
        context.read<UserPostsBloc>().add(
          RefreshUserPostsEvent(
            profileUserId: widget.userId,
            currentUserId: _currentUserId!,
          ),
        );

        // NEW: Start UserPosts real-time if not own profile
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
        // Subscribe to real-time for this profile if not own
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
      context.read<ProfileBloc>().add(StopProfileRealtimeEvent());
      // NEW: Stop UserPosts real-time
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
          //Listen to UserPostsBloc
          BlocListener<UserPostsBloc, UserPostsState>(
            listener: (context, state) {
              // Since UserPostsBloc is local to this page, we only check for mounted
              if (state is UserPostsLoaded) {
                if (mounted) {
                  setState(() {
                    _userPosts.clear();
                    _userPostsError = null;
                    _userPosts.addAll(state.posts);
                    _hasMoreUserPosts = state.hasMore;
                    _isUserPostsLoading = false;
                    _isLoadingMoreUserPosts = false;
                    _loadMoreError = null;
                    _hasLoadedOnce = true; // initial load completed
                  });
                  AppLogger.info(
                    'UserProfilePage: Loaded ${_userPosts.length} posts for ${widget.userId}',
                  );
                }
              } else if (state is UserPostsError) {
                if (mounted) {
                  setState(() {
                    _userPostsError = state.message;
                    _isUserPostsLoading = false;
                    _isLoadingMoreUserPosts = false;
                  });
                }
              } else if (state is UserPostsLoading) {
                if (mounted) {
                  setState(() {
                    _isUserPostsLoading = true;
                  });
                }
              } else if (state is UserPostsLoadMoreError) {
                if (mounted) {
                  setState(() {
                    _loadMoreError = state.message;
                    _isLoadingMoreUserPosts = false;
                  });
                }
              }
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
                // The UserPostsBloc's state update will remove it from the list.
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
                onRetry: () => context.read<ProfileBloc>().add(
                  GetProfileDataEvent(widget.userId),
                ),
              );
            }
            if (state is ProfileDataLoaded) {
              // Check if wrong user and reload (safety check)
              if (state.userId != widget.userId) {
                context.read<ProfileBloc>().add(
                  GetProfileDataEvent(widget.userId),
                );
                return const Center(child: LoadingIndicator());
              }

              // Wrap RefreshIndicator and CustomScrollView in SafeArea so bottom nav / gesture area
              // doesn't overlap content. Also add explicit bottom padding from MediaQuery.
              final bottomPadding = MediaQuery.of(context).padding.bottom;

              return SafeArea(
                top: false, // keep the AppBar handling the top safe area
                bottom: true,
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (_currentUserId != null) {
                      // Refresh posts on the local UserPostsBloc
                      context.read<UserPostsBloc>().add(
                        RefreshUserPostsEvent(
                          profileUserId: widget.userId,
                          currentUserId: _currentUserId!,
                        ),
                      );
                      if (mounted) {
                        setState(() {
                          _userPosts.clear();
                          _userPostsError = null;
                          _hasMoreUserPosts = true;
                          _hasLoadedOnce =
                              false; // reset guard for manual refresh
                        });
                      }
                    }
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Add bottom padding to ensure last item is above system nav bar
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
                      SliverPadding(
                        // Ensure posts list and footer respect bottom safe area + a little extra gap
                        padding: EdgeInsets.only(bottom: bottomPadding + 16.0),
                        sliver: ProfilePostsList(
                          posts: _userPosts,
                          userId: _currentUserId ?? '',
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
                              // FIXED: Use Refresh for reset (vs. Get)
                              context.read<UserPostsBloc>().add(
                                RefreshUserPostsEvent(
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
