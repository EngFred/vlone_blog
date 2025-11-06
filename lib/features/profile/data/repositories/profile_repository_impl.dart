import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  ProfileRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(String userId) async {
    try {
      final profileModel = await remoteDataSource.getProfile(userId);
      return Right(profileModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ProfileEntity>> updateProfile({
    required String userId,
    String? username,
    String? bio,
    XFile? profileImage,
  }) async {
    try {
      final profileModel = await remoteDataSource.updateProfile(
        userId: userId,
        username: username,
        bio: bio,
        profileImage: profileImage,
      );
      return Right(profileModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> streamProfileUpdates(
    String userId,
  ) {
    try {
      return remoteDataSource
          .streamProfileUpdates(userId)
          .map((update) => Right<Failure, Map<String, dynamic>>(update))
          .handleError((error) {
            return Left<Failure, Map<String, dynamic>>(
              ServerFailure(error.toString()),
            );
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }
}
