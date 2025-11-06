import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/presentation/widgets/loading_more_footer.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = users.length + (hasMore ? 1 : 0);

    return ListView.builder(
      controller: controller,
      key: const PageStorageKey('userListModeUsers'),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == users.length) {
          // Footer
          return LoadingMoreFooter(
            hasMore: hasMore,
            loadMoreError: loadMoreError,
            onRetry: onRetryLoadMore,
          );
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
