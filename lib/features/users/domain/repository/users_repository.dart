import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

abstract class UsersRepository {
  Future<Either<Failure, List<UserListEntity>>> getPaginatedUsers({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  });
  Stream<Either<Failure, UserListEntity>> streamNewUsers(String currentUserId);
}
