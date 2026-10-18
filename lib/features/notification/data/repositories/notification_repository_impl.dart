import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

/// Implementation of [NotificationRepository]; wraps the remote data source
/// and converts exceptions into [Failure]s.
class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({required this.remoteDataSource});

  /// Registers the device for push notifications.
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

  /// Unregisters the device (on logout).
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

  /// Streams the user's notifications.
  @override
  Stream<List<AppNotification>> getNotifications(String userId) {
    return remoteDataSource.getNotifications(userId);
  }

  /// Marks one notification as read.
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

  /// Marks all notifications as read.
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
