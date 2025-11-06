import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/presentation/widgets/cutsom_alert_dialog.dart';
import 'package:vlone_blog_app/core/presentation/widgets/debounced_inkwell.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';

class PostHeader extends StatelessWidget {
  final PostEntity post;
  final String? currentUserId;

  const PostHeader({super.key, required this.post, this.currentUserId});

  void _navigateToProfile(BuildContext context) {
    if (post.userId == currentUserId) {
      context.go('${Constants.profileRoute}/me');
    } else {
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
      leading: DebouncedInkWell(
        actionKey: 'nav_profile_${post.userId}',
        duration: const Duration(milliseconds: 500),
        onTap: () => _navigateToProfile(context),
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(2),
        child: CircleAvatar(
          radius: 20,
          backgroundImage: post.avatarUrl != null
              ? NetworkImage(post.avatarUrl!)
              : null,
          child: post.avatarUrl == null ? const Icon(Icons.person) : null,
        ),
      ),
      title: DebouncedInkWell(
        actionKey: 'nav_profile_title_${post.userId}',
        duration: const Duration(milliseconds: 300),
        onTap: () => _navigateToProfile(context),
        borderRadius: BorderRadius.circular(8),
        padding: const EdgeInsets.symmetric(vertical: 4),
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
    showCustomDialog(
      context: context,
      title: 'Delete Post?',
      content: Text(
        'This action cannot be undone. All likes, comments, and favorites will be removed.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      actions: [
        DialogActions.createCancelButton(context, label: 'Cancel'),
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            context.read<PostActionsBloc>().add(DeletePostEvent(post.id));
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
