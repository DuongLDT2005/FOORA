import '../../domain/entities/notification_settings.dart';

/// Maps `users/{uid}.notificationSettings` to [NotificationSettings].
/// Invalid fields fall back to their defaults one by one, like the backend
/// `parseSettings`.
class NotificationSettingsModel {
  const NotificationSettingsModel._();

  static NotificationSettings fromMap(Map<String, dynamic> map) {
    const d = NotificationSettings.defaults;
    final rawDays = map['expiryAlertDays'];
    final days = rawDays is List
        ? (rawDays
              .whereType<num>()
              .map((n) => n.toInt())
              .where(NotificationSettings.expiryAlertDayOptions.contains)
              .toSet()
              .toList()
            ..sort())
        : d.expiryAlertDays;
    final hour = map['reminderHour'];
    final weekday = map['shoppingReminderWeekday'];
    return NotificationSettings(
      pushEnabled: map['pushEnabled'] is bool
          ? map['pushEnabled'] as bool
          : d.pushEnabled,
      expiryAlertDays: days,
      reminderHour: hour is int && hour >= 0 && hour <= 23
          ? hour
          : d.reminderHour,
      shoppingReminderEnabled: map['shoppingReminderEnabled'] is bool
          ? map['shoppingReminderEnabled'] as bool
          : d.shoppingReminderEnabled,
      shoppingReminderWeekday: weekday is int && weekday >= 1 && weekday <= 7
          ? weekday
          : d.shoppingReminderWeekday,
    );
  }

  /// Integers stay `int` so Firestore stores them as integers (Rules use
  /// `is int`).
  static Map<String, dynamic> toMap(NotificationSettings settings) {
    return {
      'pushEnabled': settings.pushEnabled,
      'expiryAlertDays': [...settings.expiryAlertDays],
      'reminderHour': settings.reminderHour,
      'shoppingReminderEnabled': settings.shoppingReminderEnabled,
      'shoppingReminderWeekday': settings.shoppingReminderWeekday,
    };
  }
}
