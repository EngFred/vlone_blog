import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:vlone_blog_app/features/auth/domain/entities/user_entity.dart';
import 'package:vlone_blog_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final userModel = await remoteDataSource.signUp(
        email: email,
        password: password,
        username: username,
      );
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in signup repository: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.login(
        email: email,
        password: password,
      );
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in login repository: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      await remoteDataSource.logout();
      return const Right(unit);
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in logout repository: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final userModel = await remoteDataSource.getCurrentUser();
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in getCurrentUser repository: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  Future<Either<Failure, bool>> restoreSession() async {
    try {
      final restored = await remoteDataSource.restoreSession();
      return Right(restored);
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in restoreSession repository: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }
}
