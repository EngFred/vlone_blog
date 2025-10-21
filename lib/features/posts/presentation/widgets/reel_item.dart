import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_media.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_actions.dart';

class ReelItem extends StatelessWidget {
  final PostEntity post;
  final String userId;
  const ReelItem({super.key, required this.post, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background media (video/image)
        PostMedia(post: post, height: double.infinity, autoPlay: true),

        // Overlay content (header, caption, actions)
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top header (profile, more actions, etc.)
              PostHeader(post: post),

              // Bottom area: caption on bottom-left, actions pinned to the right
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Caption area - takes remaining space on the left
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          // optional: subtle background to improve readability
                          padding: const EdgeInsets.symmetric(
                            vertical: 6.0,
                            horizontal: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: post.content != null
                              ? Text(
                                  post.content!,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.2,
                                    shadows: [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    // Small gap between caption and actions
                    const SizedBox(width: 12),

                    // Actions pinned on the right (fixed width so they "forever" stay on the right)
                    // Make sure ReelActions does not try to expand horizontally
                    SizedBox(
                      width: 46, // tweak width as you like
                      child: ReelActions(post: post, userId: userId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
