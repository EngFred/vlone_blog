import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';

class PostHeader extends StatelessWidget {
  final PostEntity post;
  final String?
  currentUserId; // New: Pass from PostDetailsPage to check ownership

  const PostHeader({super.key, required this.post, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final isOwner = currentUserId == post.userId;

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
      trailing:
          isOwner // Conditional: Only show delete for owner
          ? IconButton(
              icon: const Icon(
                Icons.more_vert,
              ), // Or Icons.delete_outline for trash
              onPressed: () => _showDeleteDialog(context),
              tooltip: 'Delete Post',
            )
          : null,
      // onTap: () => context.push('/profile/${post.userId}'), <-- Removed the navigation
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'This action cannot be undone. All likes, comments, and favorites will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.read<PostsBloc>().add(DeletePostEvent(postId: post.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
