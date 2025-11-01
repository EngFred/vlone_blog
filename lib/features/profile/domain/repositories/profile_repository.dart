import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:image_picker/image_picker.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile(String userId);

  /// Update profile fields. All params optional; only provided fields will be updated.
  Future<Either<Failure, ProfileEntity>> updateProfile({
    required String userId,
    String? username,
    String? bio,
    XFile? profileImage,
  });

  Stream<Either<Failure, Map<String, dynamic>>> streamProfileUpdates(
    String userId,
  );
}
