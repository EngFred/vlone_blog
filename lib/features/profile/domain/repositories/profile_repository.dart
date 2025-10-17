import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile(String userId);

  Future<Either<Failure, ProfileEntity>> updateProfile({
    required String userId,
    String? bio,
    XFile? profileImage,
  });

  Future<Either<Failure, List<PostEntity>>> getUserPosts({
    required String userId,
    int page = 1,
    int limit = 20,
  });
}
