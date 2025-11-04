import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

// 🎯 FIX: Changed UseCase return type from PostEntity to Unit
class CreatePostUseCase implements UseCase<Unit, CreatePostParams> {
  final PostsRepository repository;

  CreatePostUseCase(this.repository);

  @override
  // 🎯 FIX: Changed call method return type from PostEntity to Unit
  Future<Either<Failure, Unit>> call(CreatePostParams params) {
    return repository.createPost(
      userId: params.userId,
      content: params.content,
      mediaFile: params.mediaFile,
      mediaType: params.mediaType,
    );
  }
}

class CreatePostParams {
  final String userId;
  final String? content;
  final File? mediaFile;
  final String? mediaType;

  CreatePostParams({
    required this.userId,
    this.content,
    this.mediaFile,
    this.mediaType,
  });
}
