import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/local_notification_service.dart';
import '../../domain/entities/weekly_reminder_config.dart';
import '../../domain/repositories/weekly_reminder_repository.dart';

class WeeklyReminderRepositoryImpl implements WeeklyReminderRepository {
  final SharedPreferences _prefs;
  final LocalNotificationService _notificationService;

  WeeklyReminderRepositoryImpl({
    required SharedPreferences prefs,
    required LocalNotificationService notificationService,
  })  : _prefs = prefs,
        _notificationService = notificationService;

  String _userKey(String userId, String suffix) {
    final sanitizedUid = userId.trim().isNotEmpty ? userId.trim() : 'anonymous';
    return 'pref_weekly_reminder_${sanitizedUid}_$suffix';
  }

  @override
  Future<WeeklyReminderConfig> getConfig(String userId) async {
    final isEnabled = _prefs.getBool(_userKey(userId, 'enabled')) ?? false;
    final dayOfWeek = _prefs.getInt(_userKey(userId, 'day')) ?? DateTime.sunday;
    final hour = _prefs.getInt(_userKey(userId, 'hour')) ?? 8;
    final minute = _prefs.getInt(_userKey(userId, 'minute')) ?? 0;

    return WeeklyReminderConfig(
      isEnabled: isEnabled,
      dayOfWeek: dayOfWeek,
      hour: hour,
      minute: minute,
    );
  }

  @override
  Future<void> saveConfig(String userId, WeeklyReminderConfig config) async {
    await _prefs.setBool(_userKey(userId, 'enabled'), config.isEnabled);
    await _prefs.setInt(_userKey(userId, 'day'), config.dayOfWeek);
    await _prefs.setInt(_userKey(userId, 'hour'), config.hour);
    await _prefs.setInt(_userKey(userId, 'minute'), config.minute);
  }

  @override
  Future<void> scheduleReminder(WeeklyReminderConfig config) async {
    await _notificationService.scheduleWeeklyReminder(
      dayOfWeek: config.dayOfWeek,
      hour: config.hour,
      minute: config.minute,
    );
  }

  @override
  Future<void> cancelReminder() async {
    await _notificationService.cancelWeeklyReminder();
  }

  @override
  Future<bool> requestPermission() async {
    return await _notificationService.requestPermission();
  }

  @override
  Future<bool> checkPermission() async {
    return await _notificationService.checkPermission();
  }
}
