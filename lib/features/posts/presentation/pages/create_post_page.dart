import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/loading_overlay.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/media_upload_widget.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/core/utils/media_progress_notifier.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  File? _mediaFile;
  String? _mediaType;
  bool _isPostButtonEnabled = false;

  // Local UI state for showing full-screen processing overlay driven by notifier.
  bool _isProcessingMedia = false;
  String _processingMessage = 'Processing...';

  /// NOTE: nullable — we only show percent for compression stage.
  /// When uploading, this stays `null` so the overlay shows an indeterminate spinner.
  double? _processingPercent;

  StreamSubscription<MediaProgress>? _progressSub;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_validatePost);
    _validatePost();

    // Subscribe to MediaProgressNotifier stream so we can show compress/upload messages
    _progressSub = MediaProgressNotifier.stream.listen((progress) {
      if (!mounted) return;

      // IMPORTANT: only show numeric percentage during compression stage.
      // Uploading will show message only (no percent) because Supabase storage
      // upload in the current flow does not provide progress callbacks.
      switch (progress.stage) {
        case MediaProcessingStage.compressing:
          setState(() {
            _isProcessingMedia = true;
            // Compression only applies to video — but be defensive:
            _processingMessage = _mediaType == 'video'
                ? 'Compressing video...'
                : 'Compressing...';
            // Use provided percent (0..100)
            _processingPercent = progress.percent.clamp(0.0, 100.0);
          });
          break;
        case MediaProcessingStage.uploading:
          setState(() {
            _isProcessingMedia = true;
            // Dynamically pick upload message based on currently-selected media type.
            // This prevents "Uploading video..." from showing when user uploads an image.
            if (_mediaType == 'image') {
              _processingMessage = 'Uploading image...';
            } else if (_mediaType == 'video') {
              _processingMessage = 'Uploading video...';
            } else {
              _processingMessage = 'Uploading...';
            }
            // IMPORTANT: clear percent so the overlay shows an indeterminate spinner
            // instead of a numeric % for upload.
            _processingPercent = null;
          });
          break;
        case MediaProcessingStage.done:
          setState(() {
            _processingPercent = 100.0;
            _processingMessage = 'Done';
            _isProcessingMedia = false;
          });
          break;
        case MediaProcessingStage.error:
          setState(() {
            _isProcessingMedia = false;
            _processingMessage = progress.message ?? 'Error processing media';
            _processingPercent = null;
          });
          // Show an error toast/snackbar
          if (progress.message != null && progress.message!.isNotEmpty) {
            SnackbarUtils.showError(context, progress.message!);
          }
          break;
        case MediaProcessingStage.idle:
          setState(() {
            _isProcessingMedia = false;
            _processingMessage = 'Processing...';
            _processingPercent = null;
          });
      }
    });
  }

  @override
  void dispose() {
    _contentController.removeListener(_validatePost);
    _contentController.dispose();
    _progressSub?.cancel();
    _progressSub = null;
    super.dispose();
  }

  void _validatePost() {
    final isEnabled =
        _contentController.text.trim().isNotEmpty || _mediaFile != null;
    if (isEnabled != _isPostButtonEnabled) {
      setState(() {
        _isPostButtonEnabled = isEnabled;
      });
    }
  }

  void _onMediaSelected(File? file, String? type) {
    setState(() {
      _mediaFile = file;
      _mediaType = type;
    });
    _validatePost();
  }

  // This callback is still supported by MediaUploadWidget for local processing (trim/preview).
  void _onProcessingChanged(bool processing) {
    if (!mounted) return;
    // We keep the existing behavior (a simple overlay), but the detailed stages now come
    // from MediaProgressNotifier during create/upload.
    setState(() {
      _isProcessingMedia = processing;
      if (!_isProcessingMedia) {
        _processingPercent = null;
        _processingMessage = 'Processing...';
      } else {
        _processingMessage = 'Processing media...';
      }
    });
  }

  // Helper: compute a consistent upload message based on current selected media.
  String get _computedUploadMessage {
    if (_mediaFile == null) return 'Uploading post...';
    if (_mediaType == 'video') return 'Uploading video...';
    if (_mediaType == 'image') return 'Uploading image...';
    return 'Uploading...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Read user id from AuthBloc reactively
    final currentUserId = context.select((AuthBloc b) => b.cachedUser?.id);

    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is PostCreated) {
          // Clear any progress notifications and pop when created
          MediaProgressNotifier.notifyDone();
          if (context.mounted) context.pop();
        } else if (state is PostsError) {
          MediaProgressNotifier.notifyError(state.message);
          SnackbarUtils.showError(context, state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Post'),
          centerTitle: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          scrolledUnderElevation: 0.0,
          elevation: 0,
          actions: [
            BlocBuilder<PostsBloc, PostsState>(
              builder: (context, state) {
                final isLoading = state is PostsLoading;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: FilledButton(
                    onPressed:
                        (currentUserId != null &&
                            _isPostButtonEnabled &&
                            !isLoading)
                        ? () {
                            // Use userId from AuthBloc
                            context.read<PostsBloc>().add(
                              CreatePostEvent(
                                userId: currentUserId,
                                content: _contentController.text.trim().isEmpty
                                    ? null
                                    : _contentController.text.trim(),
                                mediaFile: _mediaFile,
                                mediaType: _mediaType,
                              ),
                            );
                          }
                        : null,
                    // Loading is handled by overlay and bloc state; keep text simple
                    child: const Text('Post'),
                  ),
                );
              },
            ),
          ],
        ),
        // We use a Stack to layer the main content and the overlay
        body: BlocBuilder<PostsBloc, PostsState>(
          builder: (context, state) {
            // Keep previous isLoading check, but overlay is now informed by MediaProgressNotifier
            final isLoading = state is PostsLoading;
            return Stack(
              children: [
                // 1. Main Content (always visible)
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _contentController,
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            filled: true,
                            fillColor: theme.colorScheme.secondaryContainer
                                .withOpacity(0.2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: 8,
                          minLines: 3,
                        ),
                        const SizedBox(height: 20),
                        // Pass the processing callback to the widget so it can toggle the page overlay
                        MediaUploadWidget(
                          onMediaSelected: _onMediaSelected,
                          onProcessing: _onProcessingChanged,
                        ),
                      ],
                    ),
                  ),
                ),
                // 2. Loading Overlay for post upload (covers screen)
                // Previously this always said "Uploading post...". Now we compute the message
                // from the currently selected media type so it's consistent for the whole upload.
                if (isLoading && !_isProcessingMedia)
                  SavingLoadingOverlay(message: _computedUploadMessage),
                // 3. Media-processing overlay driven by MediaProgressNotifier
                // NOTE: we pass _processingPercent which is nullable. When null, overlay shows indeterminate spinner.
                if (_isProcessingMedia)
                  SavingLoadingOverlay(
                    message: _processingMessage,
                    percent: _processingPercent,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
