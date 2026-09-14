import '../entities/app_notification.dart';
import '../repositories/notification_repository.dart';

class GetNotificationsUseCase {
  final NotificationRepository _repository;

  const GetNotificationsUseCase(this._repository);

  Stream<List<AppNotification>> call(String userId) {
    return _repository.getNotifications(userId);
  }
}
