import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_actions.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_media.dart';

class PostCard extends StatefulWidget {
  final PostEntity post;
  final String userId;
  const PostCard({super.key, required this.post, required this.userId});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<PostsBloc>(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PostHeader(post: widget.post, currentUserId: widget.userId),
            if (widget.post.content != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: Text(widget.post.content!),
              ),
            if (widget.post.mediaUrl != null) const SizedBox(height: 8),
            if (widget.post.mediaUrl != null) PostMedia(post: widget.post),
            const SizedBox(height: 8),
            PostActions(post: widget.post, userId: widget.userId),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
