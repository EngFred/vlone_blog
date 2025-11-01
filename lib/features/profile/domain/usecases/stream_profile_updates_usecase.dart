import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/repositories/profile_repository.dart';

class StreamProfileUpdatesUseCase
    implements StreamUseCase<Map<String, dynamic>, String> {
  final ProfileRepository repository;

  StreamProfileUpdatesUseCase(this.repository);

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(String userId) {
    return repository.streamProfileUpdates(userId);
  }
}
