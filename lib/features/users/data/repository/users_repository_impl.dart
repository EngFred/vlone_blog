import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/users/data/datasources/users_remote_datasource.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
import 'package:vlone_blog_app/features/users/domain/repository/users_repository.dart';

class UsersRepositoryImpl implements UsersRepository {
  final UsersRemoteDataSource remoteDataSource;

  UsersRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<UserListEntity>>> getPaginatedUsers({
    required String currentUserId,
    int pageSize = 20,
    int pageOffset = 0,
  }) async {
    try {
      final userModels = await remoteDataSource.getPaginatedUsers(
        currentUserId: currentUserId,
        pageSize: pageSize,
        pageOffset: pageOffset,
      );
      return Right(userModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, UserListEntity>> streamNewUsers(String currentUserId) {
    return remoteDataSource
        .streamNewUsers(currentUserId)
        .map((model) => Right<Failure, UserListEntity>(model.toEntity()))
        .handleError((e) {
          return Left<Failure, UserListEntity>(ServerFailure(e.toString()));
        });
  }
}
