import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/loading_overlay.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/media_upload_widget.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

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

  // New: show full-screen overlay while media is being prepared
  bool _isProcessingMedia = false;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_validatePost);
    _validatePost();
  }

  @override
  void dispose() {
    _contentController.removeListener(_validatePost);
    _contentController.dispose();
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

  // Called by MediaUploadWidget to toggle the full-screen processing overlay
  void _onProcessingChanged(bool processing) {
    if (mounted) {
      setState(() {
        _isProcessingMedia = processing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Read user id from AuthBloc reactively
    final currentUserId = context.select((AuthBloc b) => b.cachedUser?.id);

    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is PostCreated) {
          // pop when created
          if (context.mounted) context.pop();
        } else if (state is PostsError) {
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
                if (isLoading)
                  const SavingLoadingOverlay(message: 'Uploading post...'),

                // 3. Loading Overlay for media processing (covers screen, above main content)
                if (_isProcessingMedia)
                  const SavingLoadingOverlay(message: 'Processing video...'),
              ],
            );
          },
        ),
      ),
    );
  }
}
