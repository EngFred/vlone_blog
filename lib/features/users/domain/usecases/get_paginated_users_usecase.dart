import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/domain/repository/users_repository.dart';

class GetPaginatedUsersUseCase
    implements UseCase<List<UserListEntity>, GetPaginatedUsersParams> {
  final UsersRepository repository;

  GetPaginatedUsersUseCase(this.repository);

  @override
  Future<Either<Failure, List<UserListEntity>>> call(
    GetPaginatedUsersParams params,
  ) {
    return repository.getPaginatedUsers(
      currentUserId: params.currentUserId,
      pageSize: params.pageSize,
      pageOffset: params.pageOffset,
    );
  }
}

class GetPaginatedUsersParams {
  final String currentUserId;
  final int pageSize;
  final int pageOffset;

  GetPaginatedUsersParams({
    required this.currentUserId,
    this.pageSize = 20,
    this.pageOffset = 0,
  });
}
