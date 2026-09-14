import '../entities/app_notification.dart';

abstract class NotificationRepository {
  /// Registers or updates device FCM token in users/{userId}/devices/{deviceId}
  Future<void> registerDevice({required String userId});

  /// Deactivates (isActive = false) device token on logout
  Future<void> unregisterDevice({required String userId});

  /// Streams real-time notifications for given user sorted by createdAt descending
  Stream<List<AppNotification>> getNotifications(String userId);

  /// Marks a single notification as read
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  });

  /// Marks all notifications of a user as read
  Future<void> markAllAsRead({required String userId});
}
