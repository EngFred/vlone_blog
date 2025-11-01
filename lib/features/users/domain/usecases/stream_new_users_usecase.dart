import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/domain/repository/users_repository.dart';

class StreamNewUsersUseCase implements StreamUseCase<UserListEntity, String> {
  final UsersRepository repository;

  StreamNewUsersUseCase(this.repository);

  @override
  Stream<Either<Failure, UserListEntity>> call(String currentUserId) {
    return repository.streamNewUsers(currentUserId);
  }
}
