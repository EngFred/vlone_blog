import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:vlone_blog_app/core/widgets/loading_overlay.dart';

class TrimmerView extends StatefulWidget {
  final File videoFile;

  /// in seconds. If null, default is 60 seconds (your 60s).
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

class _TrimmerViewState extends State<TrimmerView>
    with TickerProviderStateMixin {
  final Trimmer _trimmer = Trimmer();
  double _startValue = 0.0;
  double _endValue = 0.0;
  double _fullDurationMs = 0.0;
  bool _isPlaying = false;
  bool _progressVisibility = false; // Controls the saving overlay visibility

  // A tiny tolerance so floating rounding doesn't produce a false-negative.
  static const double _toleranceMs = 100.0;
  static const double _defaultMaxDurationSeconds = 60.0;

  double get _trimDurationMs =>
      (_endValue - _startValue).clamp(0.0, double.infinity);
  double get _effectiveMaxDurationSeconds =>
      widget.maxDuration ?? _defaultMaxDurationSeconds;
  double get _maxDurationMs => _effectiveMaxDurationSeconds * 1000.0;

  /// Save enabled only when trim duration > 0 and <= maxDuration (within tiny tolerance)
  bool get _isSaveEnabled {
    return _trimDurationMs > 0 &&
        _trimDurationMs <= (_maxDurationMs + _toleranceMs);
  }

  bool get _isOverMax => _trimDurationMs > (_maxDurationMs + _toleranceMs);
  bool get _isTooShort => _trimDurationMs <= 0;

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

  // Utility: ms -> mm:ss (or hh:mm:ss if long)
  String _formatMsToTime(double ms) {
    final int totalSeconds = (ms / 1000).round();
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    // dynamic highlight color for trim handles / border
    final Color trimHighlightColor = _isOverMax
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

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
                  duration: const Duration(milliseconds: 220),
                  child: IgnorePointer(
                    ignoring: _isPlaying,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 14,
                            spreadRadius: 1,
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

          // Bottom area: durations indicator + scrubber
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live duration indicator / warning
                _buildDurationIndicator(context, trimHighlightColor),
                const SizedBox(height: 12),
                // Trimmer scrubber
                TrimViewer(
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
                    circlePaintColor: trimHighlightColor,
                    borderPaintColor: trimHighlightColor,
                    scrubberPaintColor: trimHighlightColor.withOpacity(0.65),
                    borderRadius: 8.0,
                  ),
                  areaProperties: TrimAreaProperties(
                    borderRadius: 12.0,
                    startIcon: Icon(
                      Icons.arrow_circle_left_rounded,
                      color: trimHighlightColor,
                      size: 24,
                    ),
                    endIcon: Icon(
                      Icons.arrow_circle_right_rounded,
                      color: trimHighlightColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
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
              // Always show 'Save' in the top bar per your request.
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationIndicator(BuildContext context, Color highlightColor) {
    final theme = Theme.of(context);

    final selectedTimeText = _formatMsToTime(_trimDurationMs);
    final maxTimeText = _formatMsToTime(_maxDurationMs);

    // Message and icon for the state
    final bool showWarning = _isOverMax || _isTooShort;
    final IconData stateIcon = _isOverMax
        ? Icons.error_outline
        : (_isTooShort ? Icons.info_outline : Icons.check_circle_outline);

    // More opaque background for both valid & invalid states so text is readable on light videos.
    // Valid: semi-opaque surfaceVariant; Invalid: slightly stronger opacity.
    final Color bgColor = showWarning
        ? theme.colorScheme.surfaceVariant.withOpacity(0.46)
        : theme.colorScheme.surfaceVariant.withOpacity(0.36);

    final Color pillColor = _isOverMax
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Left: icon + messages
          Expanded(
            child: Row(
              children: [
                // round icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: pillColor.withOpacity(0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    stateIcon,
                    size: 18,
                    color: _isOverMax
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                // Text area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // top row: selected / max
                      RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                          children: [
                            TextSpan(text: 'Selection: '),
                            TextSpan(
                              text: selectedTimeText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(text: '  •  Max: '),
                            TextSpan(
                              text: maxTimeText,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // status message
                      Builder(
                        builder: (context) {
                          if (_isOverMax) {
                            return Text(
                              'Selected clip is too long — trim to $maxTimeText or shorter to save.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            );
                          } else if (_isTooShort) {
                            return Text(
                              'Select a clip (length must be greater than 0).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            );
                          } else {
                            return Text(
                              'Selection good — ready to save.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Visual pill showing percentage of allowed length and save affordance
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // numeric badge: positive 0..100 or negative -0..-100 for overflow
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isOverMax
                      ? theme.colorScheme.error.withOpacity(0.22)
                      : highlightColor.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _buildPercentText(),
                  style: TextStyle(
                    color: _isOverMax
                        ? theme.colorScheme.error
                        : highlightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // small save affordance (disabled/enabled)
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: _isSaveEnabled && !_progressVisibility
                      ? _saveVideo
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isSaveEnabled ? highlightColor : Colors.white12,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: _isSaveEnabled ? highlightColor : Colors.white38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildPercentText() {
    if (_maxDurationMs <= 0) return '';
    // ratio of trim to max
    final double ratio = _trimDurationMs / _maxDurationMs;
    if (ratio <= 1.0) {
      // positive 0..100
      final int p = (ratio * 100).round().clamp(0, 100);
      return '$p%';
    } else {
      // overflow -> negative scale from -0..-100 as selection grows from max..2*max
      final double overflowFraction =
          (_trimDurationMs - _maxDurationMs) / _maxDurationMs;
      final double neg = -(overflowFraction * 100).clamp(0.0, 100.0);
      final int p = neg.round().clamp(-100, 0);
      return '$p%';
    }
  }
}
