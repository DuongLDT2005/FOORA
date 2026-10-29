import '../entities/notification_settings.dart';
import '../repositories/notification_settings_repository.dart';

class WatchNotificationSettingsUseCase {
  final NotificationSettingsRepository _repository;

  const WatchNotificationSettingsUseCase(this._repository);

  Stream<NotificationSettings?> call(String userId) =>
      _repository.watch(userId);
}
