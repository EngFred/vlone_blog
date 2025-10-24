import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/media_upload_widget.dart';

class CreatePostPage extends StatefulWidget {
  final String userId;
  const CreatePostPage({super.key, required this.userId});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  File? _mediaFile;
  String? _mediaType;
  bool _isPostButtonEnabled = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // eliminating the need for the AuthBloc selector and the complex loading check.
    final userId = widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        scrolledUnderElevation: 0.0,
        elevation: 0,
        actions: [
          BlocBuilder<PostsBloc, PostsState>(
            builder: (context, state) {
              final isLoading = state is PostsLoading;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: FilledButton(
                  onPressed: _isPostButtonEnabled && !isLoading
                      ? () {
                          // Use the userId from the widget property
                          context.read<PostsBloc>().add(
                            CreatePostEvent(
                              userId: userId,
                              content: _contentController.text.trim().isEmpty
                                  ? null
                                  : _contentController.text.trim(),
                              mediaFile: _mediaFile,
                              mediaType: _mediaType,
                            ),
                          );
                        }
                      : null,
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Post'),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocListener<PostsBloc, PostsState>(
        listener: (context, state) {
          if (state is PostCreated) {
            // This listener now fires on the global bloc,
            // and pops the page as expected.
            context.pop();
          } else if (state is PostsError) {
            SnackbarUtils.showError(context, state.message);
          }
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    filled: true,
                    fillColor: theme.colorScheme.secondaryContainer.withOpacity(
                      0.2,
                    ),
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
                MediaUploadWidget(onMediaSelected: _onMediaSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
