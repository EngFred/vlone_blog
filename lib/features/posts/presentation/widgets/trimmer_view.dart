import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final controller = _trimmer.videoPlayerController;
      if (controller != null && controller.value.isInitialized) {
        // Use seconds (video_trimmer expects seconds)
        setState(() {
          _endValue = controller.value.duration.inSeconds.toDouble();
        });

        // Keep local _isPlaying in sync with the actual controller state
        controller.addListener(() {
          if (!mounted) return;
          final playing = controller.value.isPlaying;
          if (playing != _isPlaying) {
            setState(() => _isPlaying = playing);
          }
        });
      }
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

  Future<void> _controlPlayback() async {
    // guard: ensure controller initialized
    final controller = _trimmer.videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return;

    // toggle play/pause via trimmer helper
    bool playbackState = await _trimmer.videoPlaybackControl(
      startValue: _startValue,
      endValue: _endValue,
    );
    setState(() => _isPlaying = playbackState);
  }

  @override
  void dispose() {
    // detach listener if needed (video_player cleans up on dispose)
    _trimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // VideoViewer (no IgnorePointer)
          Center(child: VideoViewer(trimmer: _trimmer)),

          // Full-screen tappable overlay — make sure it receives hits
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior
                  .opaque, // <- critical: catches taps on transparent areas
              onTap: _controlPlayback,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: _isPlaying,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 48.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Trim viewer and progress indicator (kept as before)
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: TrimViewer(
              trimmer: _trimmer,
              viewerHeight: 60.0,
              viewerWidth: MediaQuery.of(context).size.width - 32,
              onChangeStart: (value) => _startValue = value,
              onChangeEnd: (value) => _endValue = value,
              onChangePlaybackState: (value) =>
                  setState(() => _isPlaying = value),
              editorProperties: TrimEditorProperties(
                circlePaintColor: theme.colorScheme.primary,
                borderPaintColor: theme.colorScheme.primary,
                scrubberPaintColor: theme.colorScheme.primary.withOpacity(0.6),
                borderRadius: 8.0,
              ),
              areaProperties: TrimAreaProperties(
                borderRadius: 12.0,
                startIcon: Icon(
                  Icons.arrow_circle_left_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                endIcon: Icon(
                  Icons.arrow_circle_right_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
          ),

          if (_progressVisibility)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 4,
                color: theme.colorScheme.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
      appBar: AppBar(
        title: const Text(
          'Trim Video',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _progressVisibility
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _saveVideo,
                    child: const Text('Save'),
                  ),
          ),
        ],
      ),
    );
  }
}
