import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:vlone_blog_app/core/widgets/loading_overlay.dart';

class TrimmerView extends StatefulWidget {
  final File videoFile;
  final double? maxDuration;
  final double initialStart;
  final double? initialEnd;

  const TrimmerView(
    this.videoFile, {
    super.key,
    this.maxDuration,
    this.initialStart = 0.0,
    this.initialEnd,
  });

  @override
  State<TrimmerView> createState() => _TrimmerViewState();
}

class _TrimmerViewState extends State<TrimmerView> {
  final Trimmer _trimmer = Trimmer();
  double _startValue = 0.0;
  double _endValue = 0.0;
  double _fullDurationMs = 0.0;
  bool _isPlaying = false;
  bool _progressVisibility = false; // Controls the overlay visibility

  double get _trimDurationMs => _endValue - _startValue;
  double? get _maxDurationMs =>
      widget.maxDuration != null ? (widget.maxDuration! * 1000) : null;

  bool get _isSaveEnabled {
    if (_maxDurationMs == null) return true;
    return _trimDurationMs <= (_maxDurationMs! + 100.0) && _trimDurationMs > 0;
  }

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    await _trimmer.loadVideo(videoFile: widget.videoFile);
    if (!mounted) return;

    final controller = _trimmer.videoPlayerController;
    if (controller != null && controller.value.isInitialized) {
      final fullDuration = controller.value.duration;
      final fullDurationMs = fullDuration.inMilliseconds.toDouble();

      final initialStartMs = (widget.initialStart * 1000.0).clamp(
        0.0,
        fullDurationMs,
      );
      final initialEndSec =
          widget.initialEnd ??
          widget.maxDuration ??
          fullDuration.inSeconds.toDouble();
      var initialEndMs = (initialEndSec * 1000.0);
      initialEndMs = initialEndMs.clamp(initialStartMs, fullDurationMs);

      setState(() {
        _fullDurationMs = fullDurationMs;
        _startValue = initialStartMs;
        _endValue = initialEndMs;
        _trimmer.videoPlayerController?.seekTo(
          Duration(milliseconds: _startValue.toInt()),
        );
        controller.addListener(() {
          if (!mounted) return;
          final playing = controller.value.isPlaying;
          if (playing != _isPlaying) {
            setState(() => _isPlaying = playing);
          }
        });
      });
    }
  }

  Future<void> _saveVideo() async {
    if (!_isSaveEnabled) return;
    setState(() => _progressVisibility = true);

    await _trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      storageDir: StorageDir.temporaryDirectory,
      videoFileName: 'trimmed_video_${DateTime.now().millisecondsSinceEpoch}',
      onSave: (outputPath) {
        if (!mounted) return;
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

  Future<void> _controlPlayback() async {
    final controller = _trimmer.videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return;
    bool playbackState = await _trimmer.videoPlaybackControl(
      startValue: _startValue,
      endValue: _endValue,
    );
    setState(() => _isPlaying = playbackState);
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Video player
          Center(child: VideoViewer(trimmer: _trimmer)),
          // Play/pause overlay
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _controlPlayback,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: _isPlaying,
                    child: Container(
                      // ... Play button UI ...
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

          // Trimmer scrubber
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: TrimViewer(
              trimmer: _trimmer,
              viewerHeight: 60.0,
              viewerWidth: mediaQuery.size.width - 32,
              onChangeStart: (value) {
                if (mounted) {
                  setState(() {
                    _startValue = value.clamp(0.0, _endValue);
                  });
                }
              },
              onChangeEnd: (value) {
                if (mounted) {
                  setState(() {
                    _endValue = value.clamp(_startValue, _fullDurationMs);
                  });
                }
              },
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
            const SavingLoadingOverlay(message: 'Saving Video...'),
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
            child: TextButton(
              onPressed: _isSaveEnabled && !_progressVisibility
                  ? _saveVideo
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
              ),
              child: Text(_isSaveEnabled ? 'Save' : 'Trim to save'),
            ),
          ),
        ],
      ),
      // Removed floatingActionButton for overlay; it's now in the Stack.
      // floatingActionButton: null,
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
