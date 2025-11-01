import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';

class GetNotificationsStreamUseCase
    implements StreamUseCase<List<NotificationEntity>, NoParams> {
  final NotificationsRepository repository;

  GetNotificationsStreamUseCase(this.repository);

  @override
  Stream<Either<Failure, List<NotificationEntity>>> call(NoParams params) {
    return repository.getNotificationsStream();
  }
}
