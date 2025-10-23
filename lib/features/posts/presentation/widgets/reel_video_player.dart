// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
// import 'package:vlone_blog_app/features/posts/utils/video_controller_manager.dart';

// class ReelVideoPlayer extends StatefulWidget {
//   final PostEntity post;
//   final bool shouldPlay;
//   final VoidCallback? onVideoInitialized;

//   const ReelVideoPlayer({
//     super.key,
//     required this.post,
//     required this.shouldPlay,
//     this.onVideoInitialized,
//   });

//   @override
//   State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
// }

// class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
//   VideoPlayerController? _videoController;
//   bool _initialized = false;
//   bool _isPlaying = false;
//   bool _isDisposed = false;
//   final VideoControllerManager _videoManager = VideoControllerManager();

//   @override
//   void initState() {
//     super.initState();
//     _initializeVideo();
//   }

//   Future<void> _initializeVideo() async {
//     if (_isDisposed || widget.post.mediaUrl == null) return;

//     try {
//       final controller = await _videoManager.getController(
//         widget.post.id,
//         widget.post.mediaUrl!,
//       );

//       if (_isDisposed || !mounted) {
//         _videoManager.releaseController(widget.post.id);
//         return;
//       }

//       setState(() {
//         _videoController = controller;
//         _initialized = true;
//       });

//       // Set looping for reels
//       controller.setLooping(true);

//       // Notify parent that video is ready
//       widget.onVideoInitialized?.call();

//       // Auto-play if required
//       if (widget.shouldPlay) {
//         _playVideo();
//       }
//     } catch (e) {
//       // Silently handle initialization errors
//       if (mounted) {
//         setState(() => _initialized = false);
//       }
//     }
//   }

//   void _playVideo() async {
//     if (_isDisposed || !mounted || _videoController == null || !_initialized)
//       return;

//     try {
//       await _videoController!.play();
//       if (mounted) {
//         setState(() => _isPlaying = true);
//       }
//     } catch (e) {
//       // Silently handle play errors
//     }
//   }

//   void _pauseVideo() async {
//     if (_isDisposed || !mounted || _videoController == null) return;

//     try {
//       await _videoController!.pause();
//       if (mounted) {
//         setState(() => _isPlaying = false);
//       }
//     } catch (e) {
//       // Silently handle pause errors
//     }
//   }

//   void _togglePlayPause() {
//     if (_isPlaying) {
//       _pauseVideo();
//     } else {
//       _playVideo();
//     }
//   }

//   @override
//   void didUpdateWidget(ReelVideoPlayer oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     // Handle shouldPlay changes
//     if (widget.shouldPlay != oldWidget.shouldPlay) {
//       if (widget.shouldPlay && _initialized) {
//         _playVideo();
//       } else if (!widget.shouldPlay && _initialized) {
//         _pauseVideo();
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: _togglePlayPause,
//       child: Stack(
//         fit: StackFit.expand,
//         children: [
//           // Video or thumbnail background
//           if (_initialized && _videoController != null)
//             FittedBox(
//               fit: BoxFit.cover,
//               child: SizedBox(
//                 width: _videoController!.value.size.width,
//                 height: _videoController!.value.size.height,
//                 child: VideoPlayer(_videoController!),
//               ),
//             )
//           else
//             _buildThumbnail(),

//           // Play/pause overlay
//           if (!_isPlaying)
//             Container(
//               color: Colors.black54,
//               child: const Center(
//                 child: Icon(
//                   Icons.play_arrow_rounded,
//                   size: 64,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildThumbnail() {
//     return CachedNetworkImage(
//       imageUrl: widget.post.thumbnailUrl ?? widget.post.mediaUrl!,
//       fit: BoxFit.cover,
//       placeholder: (context, url) => Container(
//         color: Colors.black,
//         child: const Center(child: CircularProgressIndicator()),
//       ),
//       errorWidget: (context, url, error) => Container(
//         color: Colors.black,
//         child: const Center(
//           child: Icon(Icons.videocam_off, color: Colors.white),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _isDisposed = true;
//     _pauseVideo();
//     if (_videoController != null) {
//       _videoManager.releaseController(widget.post.id);
//     }
//     super.dispose();
//   }
// }
