import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> registerDevice({required String userId}) async {
    try {
      await remoteDataSource.registerDevice(userId);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> unregisterDevice({required String userId}) async {
    try {
      await remoteDataSource.unregisterDevice(userId);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<AppNotification>> getNotifications(String userId) {
    return remoteDataSource.getNotifications(userId);
  }

  @override
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await remoteDataSource.markAsRead(userId, notificationId);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> markAllAsRead({required String userId}) async {
    try {
      await remoteDataSource.markAllAsRead(userId);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
