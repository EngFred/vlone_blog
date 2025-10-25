import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource remoteDataSource;

  NotificationsRepositoryImpl(this.remoteDataSource);

  @override
  Stream<Either<Failure, List<NotificationEntity>>> getNotificationsStream() {
    try {
      return remoteDataSource
          .getNotificationsStream()
          .map((notifications) {
            return Right<Failure, List<NotificationEntity>>(notifications);
          })
          .handleError((error) {
            if (error is ServerException) {
              return Left<Failure, List<NotificationEntity>>(
                ServerFailure(error.message),
              );
            }
            return Left<Failure, List<NotificationEntity>>(
              ServerFailure(error.toString()),
            );
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Stream<Either<Failure, int>> getUnreadCountStream() {
    try {
      return remoteDataSource
          .getUnreadCountStream()
          .map((count) {
            return Right<Failure, int>(count);
          })
          .handleError((error) {
            if (error is ServerException) {
              return Left<Failure, int>(ServerFailure(error.message));
            }
            return Left<Failure, int>(ServerFailure(error.toString()));
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, void>> markAllAsRead() async {
    try {
      await remoteDataSource.markAllAsRead();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    try {
      await remoteDataSource.markAsRead(notificationId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
