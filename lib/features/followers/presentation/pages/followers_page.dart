import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/followers/presentation/widgets/user_list_item.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

class FollowersPage extends StatefulWidget {
  final String userId;

  const FollowersPage({super.key, required this.userId});

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  final _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  final List<ProfileEntity> _users = [];

  @override
  void initState() {
    super.initState();
    context.read<FollowersBloc>().add(
      GetFollowersEvent(userId: widget.userId, page: _currentPage),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 && !_isLoadingMore) {
      _isLoadingMore = true;
      _currentPage++;
      context.read<FollowersBloc>().add(
        GetFollowersEvent(userId: widget.userId, page: _currentPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FollowersBloc>(
      create: (_) => sl<FollowersBloc>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Followers')),
        body: BlocBuilder<FollowersBloc, FollowersState>(
          builder: (context, state) {
            if (state is FollowersLoading && _users.isEmpty) {
              return const LoadingIndicator();
            } else if (state is FollowersError) {
              return Center(child: Text(state.message));
            } else if (state is FollowersLoaded) {
              if (_currentPage == 1) _users.clear();
              _users.addAll(state.users);
              _isLoadingMore = false;
            }
            return ListView.builder(
              controller: _scrollController,
              itemCount: _users.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _users.length) {
                  return UserListItem(user: _users[index]);
                } else {
                  return const LoadingIndicator();
                }
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
