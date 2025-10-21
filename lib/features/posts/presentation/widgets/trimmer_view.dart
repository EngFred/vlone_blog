import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';

class TrimmerView extends StatefulWidget {
  final File videoFile;

  const TrimmerView(this.videoFile, {super.key});

  @override
  State<TrimmerView> createState() => _TrimmerViewState();
}

class _TrimmerViewState extends State<TrimmerView> {
  final Trimmer _trimmer = Trimmer();

  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool _progressVisibility = false;

  @override
  void initState() {
    super.initState();
    _trimmer.loadVideo(videoFile: widget.videoFile).then((_) {
      setState(() {
        _endValue =
            _trimmer.videoPlayerController?.value.duration.inMilliseconds
                .toDouble() ??
            0.0;
      });
    });
  }

  Future<void> _saveVideo() async {
    setState(() => _progressVisibility = true);
    await _trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      storageDir: StorageDir.temporaryDirectory,
      videoFileName: 'trimmed_video_${DateTime.now().millisecondsSinceEpoch}',
      onSave: (outputPath) {
        setState(() => _progressVisibility = false);
        if (outputPath != null) {
          Navigator.pop(context, outputPath);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save trimmed video')),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trim Video')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_progressVisibility)
                const LinearProgressIndicator(backgroundColor: Colors.white),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _progressVisibility ? null : _saveVideo,
                child: const Text('Save Trimmed Video'),
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoViewer(trimmer: _trimmer),
              ),
              const SizedBox(height: 16),
              TrimViewer(
                trimmer: _trimmer,
                viewerHeight: 50.0,
                viewerWidth: MediaQuery.of(context).size.width - 24,
                onChangeStart: (value) => _startValue = value,
                onChangeEnd: (value) => _endValue = value,
                onChangePlaybackState: (value) =>
                    setState(() => _isPlaying = value),
              ),
              const SizedBox(height: 16),
              IconButton(
                iconSize: 80,
                color: Colors.white,
                onPressed: () async {
                  bool playbackState = await _trimmer.videoPlaybackControl(
                    startValue: _startValue,
                    endValue: _endValue,
                  );
                  setState(() => _isPlaying = playbackState);
                },
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
