// lib/features/profile/presentation/pages/profile_page.dart
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
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_interactions_usecase.dart';
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
    _checkIfOwnProfile();
    final bloc = context.read<ProfileBloc>();
    final currentState = bloc.state;
    if (!(currentState is ProfileDataLoaded &&
        currentState.profile.id == widget.userId)) {
      bloc.add(GetProfileDataEvent(widget.userId));
    }
    // Fetch user posts via PostsBloc
    context.read<PostsBloc>().add(GetUserPostsEvent(userId: widget.userId));
  }

  Future<void> _checkIfOwnProfile() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold(
      (failure) =>
          AppLogger.error('Failed to check current user: ${failure.message}'),
      (user) {
        if (mounted) {
          setState(() {
            _isOwnProfile = user.id == widget.userId;
            _userId = user.id;
          });
        }
      },
    );
  }

  Future<void> _fetchInteractionStates() async {
    if (_userId == null || _userPosts.isEmpty) return;
    final postIds = _userPosts.map((p) => p.id).toList();

    try {
      final result = await sl<GetPostInteractionsUseCase>()(
        GetPostInteractionsParams(userId: _userId!, postIds: postIds),
      );

      result.fold(
        (failure) {
          AppLogger.error('Failed to fetch interactions: ${failure.message}');
        },
        (interactionStates) {
          if (!mounted) return;
          setState(() {
            for (int i = 0; i < _userPosts.length; i++) {
              final post = _userPosts[i];
              _userPosts[i] = post.copyWith(
                isLiked: interactionStates.isLiked(post.id),
                isFavorited: interactionStates.isFavorited(post.id),
              );
            }
          });
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error fetching interactions: $e', error: e);
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
              // Replace dialog: navigate to the standalone EditProfilePage route
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
              // no-op; profile reload handled in events and edit page will re-trigger
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
                    _userPosts.addAll(state.posts);
                    _isUserPostsLoading = false;
                  });
                  _fetchInteractionStates();
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
                  final updatedPost = _userPosts[index].copyWith(
                    likesCount:
                        _userPosts[index].likesCount + (state.isLiked ? 1 : -1),
                    isLiked: state.isLiked,
                  );
                  setState(() => _userPosts[index] = updatedPost);
                }
              } else if (state is PostShared) {
                // Sync if needed
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoriteAdded) {
                final index = _userPosts.indexWhere(
                  (p) => p.id == state.postId,
                );
                if (index != -1 && mounted) {
                  final updatedPost = _userPosts[index].copyWith(
                    favoritesCount:
                        _userPosts[index].favoritesCount +
                        (state.isFavorited ? 1 : -1),
                    isFavorited: state.isFavorited,
                  );
                  setState(() => _userPosts[index] = updatedPost);
                }
              } else if (state is FavoritesError) {
                // Handle error if needed
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
                    GetUserPostsEvent(userId: widget.userId),
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
                            GetUserPostsEvent(userId: widget.userId),
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
