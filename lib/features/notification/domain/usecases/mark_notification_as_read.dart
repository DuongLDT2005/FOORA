import '../repositories/notification_repository.dart';

class MarkNotificationAsReadUseCase {
  final NotificationRepository _repository;

  const MarkNotificationAsReadUseCase(this._repository);

  Future<void> call({required String userId, required String notificationId}) {
    return _repository.markAsRead(
      userId: userId,
      notificationId: notificationId,
    );
  }

  Future<void> markAll({required String userId}) {
    return _repository.markAllAsRead(userId: userId);
  }
}
