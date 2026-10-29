import '../entities/weekly_reminder_config.dart';

abstract class WeeklyReminderRepository {
  /// Loads persisted configuration for [userId]. If unconfigured, returns default disabled config.
  Future<WeeklyReminderConfig> getConfig(String userId);

  /// Saves configuration for [userId] persistently.
  Future<void> saveConfig(String userId, WeeklyReminderConfig config);

  /// Schedules the weekly reminder on the device.
  Future<void> scheduleReminder(WeeklyReminderConfig config);

  /// Cancels the scheduled weekly reminder on the device.
  Future<void> cancelReminder();

  /// Requests notification permissions on the platform.
  Future<bool> requestPermission();

  /// Checks if notification permissions are granted.
  Future<bool> checkPermission();
}
