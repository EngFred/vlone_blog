import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
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
  }) async {
    try {
      final userModel = await remoteDataSource.signUp(
        email: email,
        password: password,
      );
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
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
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      await remoteDataSource.logout();
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final userModel = await remoteDataSource.getCurrentUser();
      return Right(userModel.toEntity());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on SocketException catch (_) {
      return Left(NetworkFailure('No internet connection'));
    }
  }

  @override
  Future<Either<Failure, bool>> restoreSession() async {
    try {
      final restored = await remoteDataSource.restoreSession();
      return Right(restored);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
