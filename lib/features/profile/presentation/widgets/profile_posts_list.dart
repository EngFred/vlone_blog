import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';

class ProfilePostsList extends StatefulWidget {
  final String userId;

  const ProfilePostsList({super.key, required this.userId});

  @override
  State<ProfilePostsList> createState() => _ProfilePostsListState();
}

class _ProfilePostsListState extends State<ProfilePostsList> {
  final List<PostEntity> _posts = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(
      GetUserPostsEvent(userId: widget.userId, page: _currentPage),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 && !_isLoadingMore) {
      _isLoadingMore = true;
      _currentPage++;
      context.read<ProfileBloc>().add(
        GetUserPostsEvent(userId: widget.userId, page: _currentPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      buildWhen: (prev, curr) =>
          curr is UserPostsLoaded ||
          curr is ProfileLoading ||
          curr is ProfileError,
      builder: (context, state) {
        if (state is ProfileLoading && _posts.isEmpty) {
          return const LoadingIndicator();
        } else if (state is ProfileError) {
          return EmptyStateWidget(
            message: state.message,
            icon: Icons.error_outline,
            onRetry: () {
              context.read<ProfileBloc>().add(
                GetUserPostsEvent(userId: widget.userId, page: _currentPage),
              );
            },
            actionText: 'Retry',
          );
        } else if (state is UserPostsLoaded) {
          _posts.addAll(state.posts);
          _isLoadingMore = false;
        }

        if (_posts.isEmpty) {
          return const EmptyStateWidget(
            message: 'No posts yet.',
            icon: Icons.post_add,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          controller: _scrollController,
          itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < _posts.length) {
              return PostCard(post: _posts[index]);
            } else {
              return const LoadingIndicator();
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
