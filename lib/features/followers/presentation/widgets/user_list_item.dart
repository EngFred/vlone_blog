import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

class UserListItem extends StatelessWidget {
  final ProfileEntity user;

  const UserListItem({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.profileImageUrl != null
            ? NetworkImage(user.profileImageUrl!)
            : null,
      ),
      title: Text(user.username),
      subtitle: Text(user.bio ?? ''),
      onTap: () => context.push('/profile/${user.id}'),
    );
  }
}
