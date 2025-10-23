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

        // Subtle vertical gradient at the bottom for text readability
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),

        // Overlay content (header, caption, actions)
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top header (profile, more actions, etc.)
              // The PostHeader is designed for light backgrounds, so we wrap it
              // to make the content white for reels.
              Theme(
                data: Theme.of(context).copyWith(
                  // Override icon and text colors for the reel overlay
                  iconTheme: const IconThemeData(color: Colors.white),
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                ),
                child: PostHeader(post: post),
              ),

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
                        child: post.content != null && post.content!.isNotEmpty
                            ? Text(
                                post.content!,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15, // Slightly larger text
                                  height: 1.3,
                                  // ✅ IMPROVED: Stronger text shadow for maximum readability
                                  shadows: [
                                    BoxShadow(
                                      color: Colors.black87,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),

                    // Small gap between caption and actions
                    const SizedBox(width: 12),

                    // Actions pinned on the right
                    SizedBox(
                      width:
                          50, // Slightly increased width for better tappability
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
