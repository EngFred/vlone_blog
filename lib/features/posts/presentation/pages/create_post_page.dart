import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/media_upload_widget.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  File? _mediaFile;
  String? _mediaType;

  // State variable to control button enabled state
  // Start by calculating the initial state, though usually both are null/empty
  bool _isPostButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    // Add listener to validate post on text change
    _contentController.addListener(_validatePost);

    // CRITICAL: Call validation once here to set the correct initial state
    // in case the controller was somehow initialized with text (e.g., hot restart)
    // and to set the flag based on the initial _mediaFile (which is null here).
    _validatePost();
  }

  @override
  void dispose() {
    // Clean up listener and controller
    _contentController.removeListener(_validatePost);
    _contentController.dispose();
    super.dispose();
  }

  /// Validation logic: The button is enabled if the trimmed text is NOT empty
  /// OR if a media file is present.
  void _validatePost() {
    // 💡 The logic is correct: (Text content) OR (Media content)
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
    // Validate after media is selected or removed
    // This will now enable the button if media is selected
    _validatePost();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AuthBloc, AuthState, String?>(
      selector: (state) {
        if (state is AuthAuthenticated) {
          return state.user.id;
        }
        return null;
      },
      builder: (context, userId) {
        if (userId == null) {
          context.go(Constants.loginRoute);
          return const LoadingIndicator();
        }

        return BlocProvider<PostsBloc>(
          create: (_) => sl<PostsBloc>(),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Create Post'),
              actions: [
                BlocBuilder<PostsBloc, PostsState>(
                  builder: (context, state) {
                    if (state is PostsLoading) {
                      return const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: Center(child: LoadingIndicator()),
                      );
                    }
                    return TextButton(
                      // Setting onPressed to null automatically disables the button
                      onPressed: _isPostButtonEnabled
                          ? () {
                              context.read<PostsBloc>().add(
                                CreatePostEvent(
                                  userId: userId,
                                  content:
                                      _contentController.text.trim().isEmpty
                                      ? null
                                      : _contentController.text.trim(),
                                  mediaFile: _mediaFile,
                                  mediaType: _mediaType,
                                ),
                              );
                            }
                          : null,
                      child: const Text('Post'),
                    );
                  },
                ),
              ],
            ),
            body: BlocListener<PostsBloc, PostsState>(
              listener: (context, state) {
                if (state is PostCreated) {
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
                        decoration: const InputDecoration(
                          hintText: "What's on your mind?",
                          border: InputBorder.none, // Minimal design
                        ),
                        maxLines: 8, // Give more room for text
                        minLines: 3,
                      ),
                      const SizedBox(height: 20),
                      MediaUploadWidget(onMediaSelected: _onMediaSelected),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
