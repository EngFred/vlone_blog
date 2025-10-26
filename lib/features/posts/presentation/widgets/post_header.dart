import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';

class PostHeader extends StatelessWidget {
  final PostEntity post;
  final String? currentUserId;

  const PostHeader({super.key, required this.post, this.currentUserId});

  // ✅ --- This is the new, consolidated navigation logic ---
  void _navigateToProfile(BuildContext context) {
    // Check for null just in case
    if (post.userId == null) return;

    if (post.userId == currentUserId) {
      // User is tapping their OWN profile.
      // Use context.go() to switch to the main profile tab in the ShellRoute.
      context.go('${Constants.profileRoute}/me');
    } else {
      // User is tapping ANOTHER user's profile.
      // Use context.push() to show the standalone UserProfilePage.
      context.push('${Constants.profileRoute}/${post.userId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = currentUserId == post.userId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 4.0,
      ),
      leading: GestureDetector(
        // ✅ --- Call the new helper method ---
        onTap: () => _navigateToProfile(context),
        child: CircleAvatar(
          radius: 20,
          backgroundImage: post.avatarUrl != null
              ? NetworkImage(post.avatarUrl!)
              : null,
          child: post.avatarUrl == null ? const Icon(Icons.person) : null,
        ),
      ),
      title: GestureDetector(
        // ✅ --- Call the new helper method ---
        onTap: () => _navigateToProfile(context),
        child: Text(
          post.username ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      subtitle: Text(post.formattedCreatedAt),
      trailing: isOwner
          ? IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showDeleteDialog(context),
              tooltip: 'Delete Post',
            )
          : null,
    );
  }

  void _showDeleteDialog(BuildContext context) {
    // ... (Your delete dialog logic is perfect, no changes needed)
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
              Navigator.pop(context);
              context.read<PostsBloc>().add(DeletePostEvent(post.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
