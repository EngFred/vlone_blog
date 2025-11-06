import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/presentation/widgets/end_of_list_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/list_load_more_error_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/load_more_indicator.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/presentation/widgets/user_list_item.dart';

typedef FollowToggleCallback =
    void Function(String followedId, bool isFollowing);

class UserListView extends StatelessWidget {
  final ScrollController controller;
  final List<UserListEntity> users;
  final bool hasMore;
  final String? loadMoreError;
  final Set<String> loadingUserIds;
  final String currentUserId;
  final bool isLoadingMore;
  final FollowToggleCallback onFollowToggle;
  final VoidCallback? onRetryLoadMore;
  final bool showEndOfList;

  const UserListView({
    super.key,
    required this.controller,
    required this.users,
    required this.hasMore,
    required this.loadingUserIds,
    required this.currentUserId,
    required this.onFollowToggle,
    this.loadMoreError,
    this.isLoadingMore = false,
    this.onRetryLoadMore,
    this.showEndOfList = true,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount =
        users.length +
        (hasMore || (!hasMore && showEndOfList && users.isNotEmpty) ? 1 : 0);

    return ListView.builder(
      controller: controller,
      key: const PageStorageKey('userListModeUsers'),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == users.length) {
          if (hasMore) {
            // Load more indicator or error
            if (loadMoreError != null) {
              return LoadMoreErrorIndicator(
                message: loadMoreError!,
                onRetry: onRetryLoadMore ?? () {},
                horizontalMargin: 16.0,
              );
            } else {
              return LoadMoreIndicator(
                message: 'Loading more users...',
                indicatorSize: 20.0,
                spacing: 12.0,
              );
            }
          } else if (showEndOfList && users.isNotEmpty) {
            return EndOfListIndicator(
              message: "You've reached the end",
              icon: Icons.people_outline,
              iconSize: 24.0,
              spacing: 12.0,
            );
          } else {
            return const SizedBox.shrink();
          }
        }

        final user = users[index];
        return UserListItem(
          key: ValueKey(user.id),
          user: user,
          currentUserId: currentUserId,
          isLoading: loadingUserIds.contains(user.id),
          onFollowToggle: (followedId, isFollowing) {
            onFollowToggle(followedId, isFollowing);
          },
        );
      },
    );
  }
}
