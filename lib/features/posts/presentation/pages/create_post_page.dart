import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
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

  void _onMediaSelected(File? file, String? type) {
    setState(() {
      _mediaFile = file;
      _mediaType = type;
    });
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
              // UI/UX 1: Move the "Post" button to the AppBar
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
                      onPressed: () {
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
                      },
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              // FIX 1: Wrap the body in a SingleChildScrollView
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // UI/UX 5: Use hintText for a cleaner look
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
                      MediaUploadWidget(
                        onMediaSelected: _onMediaSelected,
                        // The `key` property has been removed from here.
                      ),
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
