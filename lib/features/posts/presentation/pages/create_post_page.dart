import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
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
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (user) => setState(() => _userId = user.id),
    );
    if (_userId == null) {
      context.go(Constants.loginRoute);
    }
  }

  void _onMediaSelected(File? file, String? type) {
    _mediaFile = file;
    _mediaType = type;
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const LoadingIndicator();

    return BlocProvider<PostsBloc>(
      create: (_) => sl<PostsBloc>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Post')),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content/Caption',
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 20),
                MediaUploadWidget(onMediaSelected: _onMediaSelected),
                const SizedBox(height: 20),
                BlocBuilder<PostsBloc, PostsState>(
                  builder: (context, state) {
                    if (state is PostsLoading) return const LoadingIndicator();
                    return ElevatedButton(
                      onPressed: () {
                        context.read<PostsBloc>().add(
                          CreatePostEvent(
                            userId: _userId!,
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
          ),
        ),
      ),
    );
  }
}
