import 'dart:async';

/// A simple notifier used for publishing media processing stages and percentage
/// updates between the data layer (like PostsRemoteDataSource) and the UI (like CreatePostPage).
enum MediaProcessingStage { idle, compressing, uploading, done, error }

class MediaProgress {
  final MediaProcessingStage stage;

  /// The completion percentage of the current stage, ranging from 0.0 to 100.0.
  final double percent;
  final String? message;

  const MediaProgress({
    required this.stage,
    required this.percent,
    this.message,
  });

  /// Creating a copy of the current progress state, optionally replacing specified fields.
  MediaProgress copyWith({
    MediaProcessingStage? stage,
    double? percent,
    String? message,
  }) {
    return MediaProgress(
      stage: stage ?? this.stage,
      percent: percent ?? this.percent,
      message: message ?? this.message,
    );
  }
}

class MediaProgressNotifier {
  static final StreamController<MediaProgress> _ctrl =
      StreamController<MediaProgress>.broadcast();

  /// The stream that listeners in the UI can subscribe to for real-time updates.
  static Stream<MediaProgress> get stream => _ctrl.stream;

  /// Publishing a new progress update to all active listeners.
  static void notify(MediaProgress progress) {
    try {
      if (!_ctrl.isClosed) _ctrl.add(progress);
    } catch (_) {
      // Ignoring errors if adding to the stream fails.
    }
  }

  /// Helper for notifying that the media is currently being compressed.
  static void notifyCompressing(double percent) => notify(
    MediaProgress(stage: MediaProcessingStage.compressing, percent: percent),
  );

  /// Helper for notifying that the media is currently being uploaded.
  static void notifyUploading(double percent) => notify(
    MediaProgress(stage: MediaProcessingStage.uploading, percent: percent),
  );

  /// Helper for notifying that all processing and uploading is successfully complete.
  static void notifyDone() => notify(
    const MediaProgress(stage: MediaProcessingStage.done, percent: 100.0),
  );

  /// Helper for notifying that an error occurred during the media processing pipeline.
  static void notifyError(String message) => notify(
    MediaProgress(
      stage: MediaProcessingStage.error,
      percent: 0.0,
      message: message,
    ),
  );

  /// Closing the stream controller (primarily useful for testing and cleanup).
  static Future<void> dispose() async {
    try {
      await _ctrl.close();
    } catch (_) {
      // Ignoring errors during close.
    }
  }
}
