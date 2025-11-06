import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/common/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reels/reel_video_player.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reels/reel_actions.dart';

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
  // `_currentPost` state is REMOVED

  @override
  bool get wantKeepAlive => true; // Kept for PageView performance

  @override
  void initState() {
    super.initState();
    // All logic REMOVED
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // All logic REMOVED
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ... (lightContrastTheme definition is unchanged) ...
    final lightContrastTheme = Theme.of(context).copyWith(
      iconTheme: const IconThemeData(color: Colors.white),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white,
        textColor: Colors.white,
      ),
      dialogTheme: Theme.of(context).dialogTheme.copyWith(
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.black),
        contentTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.light,
        onSurface: Colors.black,
        onSurfaceVariant: Colors.black54,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        ReelVideoPlayer(
          post: widget.post, // Use `widget.post`
          isActive: widget.isActive,
          shouldPreload: widget.isPrevious || widget.isNext,
        ),

        // ... (Gradients and overlays are unchanged) ...
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.4), Colors.transparent],
              ),
            ),
          ),
        ),

        SafeArea(
          // The MultiBlocListener is REMOVED from here
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Theme(
                data: lightContrastTheme,
                child: PostHeader(
                  post: widget.post, // Use `widget.post`
                  currentUserId: widget.userId,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.post.content !=
                                  null && // Use `widget.post`
                              widget.post.content!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                widget.post.content!, // Use `widget.post`
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 12,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 4,
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.music_note,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Original Sound',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ReelActions(
                      post: widget.post, // Use `widget.post`
                      userId: widget.userId,
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
