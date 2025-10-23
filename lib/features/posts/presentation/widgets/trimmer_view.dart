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
          if (!mounted) return;
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trim Video'),
        // ✨ UI/UX: Clean, modern AppBar
        scrolledUnderElevation: 0.0,
        elevation: 0,
        actions: [
          // ✨ UI/UX: Moved "Save" to the AppBar, the conventional place
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _progressVisibility
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(onPressed: _saveVideo, child: const Text('Save')),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✨ UI/UX: Removed save button from here
              if (_progressVisibility) const LinearProgressIndicator(),
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
                editorProperties: TrimEditorProperties(
                  circlePaintColor: theme.colorScheme.primary,
                  borderPaintColor: theme.colorScheme.primary,
                  scrubberPaintColor: theme.colorScheme.primary.withOpacity(
                    0.6,
                  ),
                ),
                areaProperties: TrimAreaProperties(
                  borderRadius: 8.0,
                  startIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  endIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ✨ UI/UX: Replaced giant IconButton with a standard FilledButton
              FilledButton.icon(
                onPressed: () async {
                  bool playbackState = await _trimmer.videoPlaybackControl(
                    startValue: _startValue,
                    endValue: _endValue,
                  );
                  setState(() => _isPlaying = playbackState);
                },
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? 'Pause' : 'Play'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
