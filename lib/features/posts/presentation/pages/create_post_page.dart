import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_overlay.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/media_upload_widget.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize controller with bloc value if any
    final bloc = context.read<PostActionsBloc>();
    final formState = bloc.state is PostFormState
        ? (bloc.state as PostFormState)
        : null;
    if (formState != null && formState.content.isNotEmpty) {
      _contentController.text = formState.content;
    }

    // Dispatch ContentChanged on text changes (debounce not needed here).
    _contentController.addListener(() {
      context.read<PostActionsBloc>().add(
        ContentChanged(_contentController.text),
      );
    });
  }

  @override
  void dispose() {
    _contentController.removeListener(() {});
    _contentController.dispose();
    super.dispose();
  }

  void _submit(String userId) {
    // In the UI we simply dispatch CreatePostEvent without repeating content/media
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
          // done processing media
          if (context.mounted) context.pop();
        } else if (state is PostActionError) {
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

            // Keep controller in sync if the form.content changed externally (e.g. optimistic resets)
            if (_contentController.text != form.content) {
              // avoid moving cursor if possible
              final selection = _contentController.selection;
              _contentController.text = form.content;
              _contentController.selection = selection.copyWith(
                baseOffset: form.content.length.clamp(0, form.content.length),
                extentOffset: form.content.length.clamp(0, form.content.length),
              );
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 90.0),
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
                          enabledBorder: form.isOverLimit
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
                          focusedBorder: form.isOverLimit
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
                        ),
                        maxLines: 8,
                        minLines: 3,
                        maxLength: null,
                      ),

                      // Character counter
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

                      const SizedBox(height: 20),

                      MediaUploadWidget(
                        onMediaSelected: (file, type) {
                          // dispatch event to bloc
                          context.read<PostActionsBloc>().add(
                            MediaSelected(file, type),
                          );
                        },
                        onProcessing: (processing) {
                          // if MediaUploadWidget needs to inform processing explicitly, it can
                          // call this — but the bloc already subscribes to MediaProgressNotifier
                          context.read<PostActionsBloc>().add(
                            ProcessingChanged(processing: processing),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                if (isLoading && !form.isProcessing)
                  SavingLoadingOverlay(message: form.computedUploadMessage),

                if (form.isProcessing)
                  SavingLoadingOverlay(
                    message: form.processingMessage,
                    percent: form.processingPercent,
                  ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 16.0,
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
