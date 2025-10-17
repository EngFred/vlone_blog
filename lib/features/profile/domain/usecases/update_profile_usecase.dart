import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase
    implements UseCase<ProfileEntity, UpdateProfileParams> {
  final ProfileRepository repository;

  UpdateProfileUseCase(this.repository);

  @override
  Future<Either<Failure, ProfileEntity>> call(UpdateProfileParams params) {
    return repository.updateProfile(
      userId: params.userId,
      bio: params.bio,
      profileImage: params.profileImage,
    );
  }
}

class UpdateProfileParams {
  final String userId;
  final String? bio;
  final XFile? profileImage; // Changed to XFile for upload

  UpdateProfileParams({required this.userId, this.bio, this.profileImage});
}
