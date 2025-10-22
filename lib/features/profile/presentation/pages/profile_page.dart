import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';

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

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ProfileBloc>();
    final currentState = bloc.state;
    if (!(currentState is ProfileDataLoaded &&
        currentState.profile.id == widget.userId)) {
      bloc.add(GetProfileDataEvent(widget.userId));
    }
    _checkIfOwnProfile();

    // Start real-time updates
    bloc.add(StartProfileRealtimeEvent(widget.userId));
  }

  @override
  void dispose() {
    context.read<ProfileBloc>().add(StopProfileRealtimeEvent());
    super.dispose();
  }

  Future<void> _checkIfOwnProfile() async {
    AppLogger.info('Checking if own profile for userId: ${widget.userId}');
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold(
      (failure) {
        AppLogger.error('Failed to current user: ${failure.message}');
        if (mounted) {
          setState(() => _userPostsError = failure.message);
        }
      },
      (user) {
        if (!mounted) return;
        setState(() {
          _isOwnProfile = user.id == widget.userId;
          _userId = user.id;
        });
        AppLogger.info('User loaded, _userId: $_userId, isOwn: $_isOwnProfile');

        final postsState = context.read<PostsBloc>().state;
        if (postsState is UserPostsLoaded &&
            postsState.posts.any((p) => p.userId == widget.userId)) {
          AppLogger.info('Using cached user posts from PostsBloc');
          if (mounted) {
            setState(() {
              _userPosts.clear();
              // FIX: Clamp counts when setting from cache
              _userPosts.addAll(
                postsState.posts.map(
                  (p) => p.copyWith(
                    likesCount: p.likesCount.clamp(0, double.infinity).toInt(),
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
            });
          }
        } else {
          AppLogger.info('Fetching user posts for profile: ${widget.userId}');
          context.read<PostsBloc>().add(
            GetUserPostsEvent(
              profileUserId: widget.userId,
              viewerUserId: _userId,
            ),
          );
        }
      },
    );
  }

  void _handleRealtimePostUpdate(RealtimePostUpdate state) {
    final index = _userPosts.indexWhere((p) => p.id == state.postId);
    if (index != -1 && mounted) {
      final post = _userPosts[index];
      // FIX: Clamp to prevent negative counts from real-time updates
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push(
                '${Constants.profileRoute}/${widget.userId}/edit',
              ),
            ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) {
              // Profile reload handled in events
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
                    // FIX: Clamp counts when setting from loaded state
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
                  // FIX: Clamp to prevent negative counts
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
                  // FIX: Add handling for PostFavorited with clamping
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
              } else if (state is PostsError) {
                // FIX: Log silently for interaction errors; no toasts
                AppLogger.error('PostsError in ProfilePage: ${state.message}');
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
              return Center(
                child: CustomErrorWidget(
                  message: state.message,
                  onRetry: () {
                    context.read<ProfileBloc>().add(
                      GetProfileDataEvent(widget.userId),
                    );
                  },
                ),
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
                      ),
                      ProfilePostsList(
                        posts: _userPosts,
                        userId: _userId ?? '',
                        isLoading: _isUserPostsLoading,
                        error: _userPostsError,
                        onRetry: () {
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
