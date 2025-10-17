import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

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
    context.read<PostsBloc>().add(
      GetUserPostsEvent(userId: widget.userId, page: _currentPage),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 && !_isLoadingMore) {
      _isLoadingMore = true;
      _currentPage++;
      context.read<PostsBloc>().add(
        GetUserPostsEvent(userId: widget.userId, page: _currentPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is UserPostsLoaded) {
          _posts.addAll(state.posts);
          _isLoadingMore = false;
        }
      },
      child: ListView.builder(
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
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
