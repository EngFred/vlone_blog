import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

class PostHeader extends StatelessWidget {
  final PostEntity post;
  const PostHeader({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 4.0,
      ),
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: post.avatarUrl != null
            ? NetworkImage(post.avatarUrl!)
            : null,
        child: post.avatarUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(
        post.username ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(post.formattedCreatedAt),
      onTap: () => context.push('/profile/${post.userId}'),
    );
  }
}
