import '../entities/notification_settings.dart';
import '../repositories/notification_settings_repository.dart';

class SaveNotificationSettingsUseCase {
  final NotificationSettingsRepository _repository;

  const SaveNotificationSettingsUseCase(this._repository);

  Future<void> call(String userId, NotificationSettings settings) {
    if (settings.reminderHour < 0 || settings.reminderHour > 23) {
      throw ArgumentError.value(settings.reminderHour, 'reminderHour');
    }
    if (settings.shoppingReminderWeekday < 1 ||
        settings.shoppingReminderWeekday > 7) {
      throw ArgumentError.value(
        settings.shoppingReminderWeekday,
        'shoppingReminderWeekday',
      );
    }
    final invalidDays = settings.expiryAlertDays.where(
      (d) => !NotificationSettings.expiryAlertDayOptions.contains(d),
    );
    if (invalidDays.isNotEmpty) {
      throw ArgumentError.value(settings.expiryAlertDays, 'expiryAlertDays');
    }
    return _repository.save(userId, settings);
  }
}
