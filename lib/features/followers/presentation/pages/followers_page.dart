import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
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
    AppLogger.info('Initializing FollowersPage for user: ${widget.userId}');
    context.read<FollowersBloc>().add(
      GetFollowersEvent(userId: widget.userId, page: _currentPage),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 && !_isLoadingMore) {
      _isLoadingMore = true;
      _currentPage++;
      AppLogger.info(
        'Fetching more followers for user: ${widget.userId}, page: $_currentPage',
      );
      context.read<FollowersBloc>().add(
        GetFollowersEvent(userId: widget.userId, page: _currentPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: BlocConsumer<FollowersBloc, FollowersState>(
        listener: (context, state) {
          if (state is FollowersLoaded) {
            AppLogger.info(
              'Followers loaded with ${state.users.length} users for user: ${widget.userId}',
            );
            if (_currentPage == 1) _users.clear();
            _users.addAll(state.users);
            _isLoadingMore = false;
          } else if (state is FollowersError) {
            AppLogger.error('Followers load failed: ${state.message}');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is FollowersLoading && _users.isEmpty) {
            return const LoadingIndicator();
          } else if (state is FollowersError) {
            return EmptyStateWidget(
              message: state.message,
              icon: Icons.error_outline,
              onRetry: () {
                AppLogger.info(
                  'Retrying followers load for user: ${widget.userId}, page: $_currentPage',
                );
                context.read<FollowersBloc>().add(
                  GetFollowersEvent(userId: widget.userId, page: _currentPage),
                );
              },
              actionText: 'Retry',
            );
          } else if (_users.isEmpty) {
            return const EmptyStateWidget(
              message: 'No followers yet.',
              icon: Icons.people_outline,
            );
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
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing FollowersPage, cleaning up scroll controller');
    _scrollController.dispose();
    super.dispose();
  }
}
