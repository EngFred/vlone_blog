// features/notifications/domain/usecases/get_unread_count_stream_usecase.dart

import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';

class GetUnreadCountStreamUseCase implements StreamUseCase<int, NoParams> {
  final NotificationsRepository repository;

  GetUnreadCountStreamUseCase(this.repository);

  @override
  Stream<Either<Failure, int>> call(NoParams params) {
    return repository.getUnreadCountStream();
  }
}
