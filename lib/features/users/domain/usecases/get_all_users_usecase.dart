import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/domain/repository/users_repository.dart';

class GetAllUsersUseCase implements UseCase<List<UserListEntity>, String> {
  final UsersRepository repository;

  GetAllUsersUseCase(this.repository);

  @override
  Future<Either<Failure, List<UserListEntity>>> call(String currentUserId) {
    return repository.getAllUsers(currentUserId);
  }
}
