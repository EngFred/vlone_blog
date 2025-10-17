import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class FavoriteItem extends StatelessWidget {
  final PostEntity post;

  const FavoriteItem({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return PostCard(post: post);
  }
}
