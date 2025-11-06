import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/media_file_type.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

/// Use case for creating a new post.
///
/// Returns [Unit] upon successful post creation, or [Failure] on error.
class CreatePostUseCase implements UseCase<Unit, CreatePostParams> {
  final PostsRepository repository;

  CreatePostUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(CreatePostParams params) {
    return repository.createPost(
      userId: params.userId,
      content: params.content,
      mediaFile: params.mediaFile,
      mediaType: params.mediaType,
    );
  }
}

/// Parameters required for [CreatePostUseCase].
class CreatePostParams {
  final String userId;
  final String? content;
  final File? mediaFile;
  final MediaType? mediaType;

  CreatePostParams({
    required this.userId,
    this.content,
    this.mediaFile,
    this.mediaType,
  });
}
