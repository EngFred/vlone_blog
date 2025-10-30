// core/utils/media_progress_notifier.dart
import 'dart:async';

/// Simple notifier used to publish media processing stages & percentage
/// between the data-layer (PostsRemoteDataSource) and UI (CreatePostPage).
enum MediaProcessingStage { idle, compressing, uploading, done, error }

class MediaProgress {
  final MediaProcessingStage stage;

  /// 0..100
  final double percent;
  final String? message;

  const MediaProgress({
    required this.stage,
    required this.percent,
    this.message,
  });

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

  /// Stream you can listen to in the UI.
  static Stream<MediaProgress> get stream => _ctrl.stream;

  /// Publish a progress update.
  static void notify(MediaProgress progress) {
    try {
      if (!_ctrl.isClosed) _ctrl.add(progress);
    } catch (_) {}
  }

  /// Helper shortcuts
  static void notifyCompressing(double percent) => notify(
    MediaProgress(stage: MediaProcessingStage.compressing, percent: percent),
  );

  static void notifyUploading(double percent) => notify(
    MediaProgress(stage: MediaProcessingStage.uploading, percent: percent),
  );

  static void notifyDone() => notify(
    const MediaProgress(stage: MediaProcessingStage.done, percent: 100.0),
  );

  static void notifyError(String message) => notify(
    MediaProgress(
      stage: MediaProcessingStage.error,
      percent: 0.0,
      message: message,
    ),
  );

  /// Close stream (not necessary in normal app lifetime, but provided for tests/cleanup)
  static Future<void> dispose() async {
    try {
      await _ctrl.close();
    } catch (_) {}
  }
}
