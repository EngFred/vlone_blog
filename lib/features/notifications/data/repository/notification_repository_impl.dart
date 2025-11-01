import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource remoteDataSource;

  NotificationsRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<NotificationEntity>>> getPaginatedNotifications({
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      final userId = remoteDataSource.client.auth.currentUser?.id;
      if (userId == null) {
        return Left(ServerFailure('User not authenticated.'));
      }
      final models = await remoteDataSource.getPaginatedNotifications(
        userId: userId,
        pageSize: pageSize,
        lastCreatedAt: lastCreatedAt,
        lastId: lastId,
      );
      return Right(models.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<NotificationEntity>>> getNotificationsStream() {
    try {
      return remoteDataSource
          .getNotificationsStream()
          .map(
            (
              notifications,
            ) => // Assuming notifications is List<NotificationModel>
            Right<Failure, List<NotificationEntity>>(
              notifications
                  .map((n) => n.toEntity())
                  .toList(), // Map to entities
            ),
          )
          .handleError((error) {
            if (error is ServerException) {
              return Stream.value(
                Left<Failure, List<NotificationEntity>>(
                  // Explicit type for value
                  ServerFailure(error.message),
                ),
              );
            }
            return Stream.value(
              Left<Failure, List<NotificationEntity>>(
                // Explicit type for value
                ServerFailure(error.toString()),
              ),
            );
          });
    } catch (e) {
      return Stream.value(
        Left<Failure, List<NotificationEntity>>(ServerFailure(e.toString())),
      );
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

  @override
  Future<Either<Failure, void>> deleteNotifications(
    List<String> notificationIds,
  ) async {
    try {
      await remoteDataSource.deleteNotifications(notificationIds);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
