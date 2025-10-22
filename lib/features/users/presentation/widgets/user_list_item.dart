import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

class UserListItem extends StatelessWidget {
  final UserListEntity user;
  final String currentUserId;
  final Function(String, bool) onFollowToggle;

  const UserListItem({
    super.key,
    required this.user,
    required this.currentUserId,
    required this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.profileImageUrl != null
            ? NetworkImage(user.profileImageUrl!)
            : null,
        child: user.profileImageUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(user.username),
      subtitle: Text(user.bio ?? 'No bio'),
      trailing: ElevatedButton(
        onPressed: () => onFollowToggle(user.id, !user.isFollowing),
        style: ElevatedButton.styleFrom(
          backgroundColor: user.isFollowing ? Colors.grey : null,
          foregroundColor: user.isFollowing ? Colors.white : null,
        ),
        child: Text(user.isFollowing ? 'Following' : 'Follow'),
      ),
      onTap: () => context.push('${Constants.profileRoute}/${user.id}'),
    );
  }
}
