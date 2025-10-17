import 'dart:io';
import 'package:video_player/video_player.dart';

Future<int> getVideoDuration(File videoFile) async {
  final controller = VideoPlayerController.file(videoFile);
  await controller.initialize();
  final duration = controller.value.duration.inSeconds;
  await controller.dispose();
  return duration;
}
