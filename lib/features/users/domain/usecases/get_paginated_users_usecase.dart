import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/domain/repository/users_repository.dart';
import 'package:equatable/equatable.dart';

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
      lastCreatedAt: params.lastCreatedAt,
      lastId: params.lastId,
    );
  }
}

class GetPaginatedUsersParams extends Equatable {
  final String currentUserId;
  final int pageSize;
  final DateTime? lastCreatedAt;
  final String? lastId;

  const GetPaginatedUsersParams({
    required this.currentUserId,
    this.pageSize = 20,
    this.lastCreatedAt,
    this.lastId,
  });

  @override
  List<Object?> get props => [currentUserId, pageSize, lastCreatedAt, lastId];
}
