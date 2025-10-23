import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_video_player.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_actions.dart';

class ReelItem extends StatefulWidget {
  final PostEntity post;
  final String userId;
  final bool isActive;
  final bool isPrevious;
  final bool isNext;

  const ReelItem({
    super.key,
    required this.post,
    required this.userId,
    required this.isActive,
    this.isPrevious = false,
    this.isNext = false,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); //Required for AutomaticKeepAliveClientMixin

    return Stack(
      fit: StackFit.expand,
      children: [
        //Dedicated reel video player with proper lifecycle management
        ReelVideoPlayer(
          post: widget.post,
          isActive: widget.isActive,
          shouldPreload: widget.isPrevious || widget.isNext,
        ),

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
              // Top header
              Theme(
                data: Theme.of(context).copyWith(
                  iconTheme: const IconThemeData(color: Colors.white),
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                ),
                child: PostHeader(post: widget.post),
              ),

              // Bottom area: caption on bottom-left, actions pinned to the right
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Caption area
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child:
                            widget.post.content != null &&
                                widget.post.content!.isNotEmpty
                            ? Text(
                                widget.post.content!,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.3,
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

                    const SizedBox(width: 12),

                    // Actions pinned on the right
                    SizedBox(
                      width: 50,
                      child: ReelActions(
                        post: widget.post,
                        userId: widget.userId,
                      ),
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
