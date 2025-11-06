import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_overlay.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/create/media_upload_widget.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'dart:ui';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  bool _isProgrammaticControllerChange = false;

  @override
  void initState() {
    super.initState();

    // Resetting form state on page entry for fresh UI
    context.read<PostActionsBloc>().add(const ResetForm());

    // Initializing controller with bloc value if any (after reset, it'll be empty)
    final bloc = context.read<PostActionsBloc>();
    final formState = bloc.state is PostFormState
        ? (bloc.state as PostFormState)
        : null;
    if (formState != null && formState.content.isNotEmpty) {
      // setting initial text *before* adding the listener to avoid firing
      _contentController.text = formState.content;
    }

    // Dispatching ContentChanged on text changes (debounce not needed here).
    _contentController.addListener(_onContentControllerChanged);
  }

  void _onContentControllerChanged() {
    if (_isProgrammaticControllerChange) return;
    context.read<PostActionsBloc>().add(
      ContentChanged(_contentController.text),
    );
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentControllerChanged);
    _contentController.dispose();
    super.dispose();
  }

  void _submit(String userId) {
    // Here we simply dispatch CreatePostEvent without repeating content/media
    // so the bloc uses current PostFormState values (or fallback to event values if provided).
    context.read<PostActionsBloc>().add(CreatePostEvent(userId: userId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = context.select((AuthBloc b) => b.cachedUser?.id);

    return BlocListener<PostActionsBloc, PostActionsState>(
      listener: (context, state) {
        if (state is PostCreatedSuccess) {
          SnackbarUtils.showSuccess(context, 'Post created!');
          if (context.mounted) context.pop();
        } else if (state is PostActionError) {
          SnackbarUtils.showError(context, state.message);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset:
            false, // Added to Prevent resizing when keyboard opens for overlay stability
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
            BlocBuilder<PostActionsBloc, PostActionsState>(
              builder: (context, state) {
                final isLoading = state is PostActionLoading;
                final form = state is PostFormState
                    ? state
                    : const PostFormState();
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: FilledButton(
                    onPressed:
                        (currentUserId != null &&
                            form.isPostButtonEnabled &&
                            !isLoading &&
                            !form.isOverLimit)
                        ? () => _submit(currentUserId)
                        : null,
                    child: const Text('Post'),
                  ),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<PostActionsBloc, PostActionsState>(
          builder: (context, state) {
            final isLoading = state is PostActionLoading;
            final form = state is PostFormState ? state : const PostFormState();
            final hasMedia = form.mediaFile != null;

            // Keeps controller in sync if the form.content changed externally (e.g. optimistic resets)
            if (_contentController.text != form.content) {
              // avoids moving cursor if possible and avoid firing listener
              final selection = _contentController.selection;
              _isProgrammaticControllerChange = true;
              _contentController.text = form.content;
              _contentController.selection = selection.copyWith(
                baseOffset: form.content.length.clamp(0, form.content.length),
                extentOffset: form.content.length.clamp(0, form.content.length),
              );
              _isProgrammaticControllerChange = false;
            }

            Widget captionWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: hasMedia
                        ? 'Add a caption...'
                        : "What's on your mind?",
                    hintStyle: hasMedia
                        ? TextStyle(color: Colors.white.withOpacity(0.7))
                        : null,
                    filled: !hasMedia,
                    fillColor: hasMedia
                        ? null
                        : theme.colorScheme.secondaryContainer.withOpacity(0.2),
                    border: hasMedia
                        ? InputBorder.none
                        : OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                    enabledBorder: hasMedia
                        ? InputBorder.none
                        : form.isOverLimit
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                              width: 2,
                            ),
                          )
                        : OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                    focusedBorder: hasMedia
                        ? InputBorder.none
                        : form.isOverLimit
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                              width: 2,
                            ),
                          )
                        : OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: hasMedia ? const TextStyle(color: Colors.white) : null,
                  maxLines: hasMedia ? null : 8,
                  minLines: hasMedia ? 1 : 3,
                  maxLength: null,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 4.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${form.currentCharCount} / ${form.maxCharacterLimit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: form.isOverLimit
                            ? theme.colorScheme.error
                            : form.isNearLimit
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: form.isOverLimit || form.isNearLimit
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                if (form.isOverLimit)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Post exceeds maximum character limit',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );

            return Stack(
              children: [
                if (!hasMedia)
                  SafeArea(
                    top: true,
                    bottom: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        16.0,
                        16.0,
                        16.0,
                        16.0,
                      ),
                      child: Column(
                        children: [
                          captionWidget,
                          const SizedBox(height: 20),
                          MediaUploadWidget(
                            selectedMediaFile: form.mediaFile,
                            selectedMediaType: form.mediaType,
                            onMediaSelected: (file, type) {
                              context.read<PostActionsBloc>().add(
                                MediaSelected(file, type),
                              );
                            },
                            onProcessing: (processing) {
                              context.read<PostActionsBloc>().add(
                                ProcessingChanged(processing: processing),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  )
                else
                  SafeArea(
                    top: true,
                    bottom: false,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MediaUploadWidget(
                          selectedMediaFile: form.mediaFile,
                          selectedMediaType: form.mediaType,
                          onMediaSelected: (file, type) {
                            context.read<PostActionsBloc>().add(
                              MediaSelected(file, type),
                            );
                          },
                          onProcessing: (processing) {
                            context.read<PostActionsBloc>().add(
                              ProcessingChanged(processing: processing),
                            );
                          },
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  color: theme.colorScheme.surface.withOpacity(
                                    0.2,
                                  ),
                                  child: captionWidget,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isLoading && !form.isProcessing)
                  SavingLoadingOverlay(message: form.computedUploadMessage),

                if (form.isProcessing)
                  SavingLoadingOverlay(
                    message: form.processingMessage,
                    percent: form.processingMessage.contains('Compressing')
                        ? form.processingPercent
                        : null,
                  ),

                // Bottom info text: Only show when no media to avoid overlap with caption overlay
                if (!hasMedia)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: 16.0 + MediaQuery.of(context).padding.bottom,
                        left: 16.0,
                        right: 16.0,
                      ),
                      child: Text(
                        'Large videos and images will be compressed before uploading.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
