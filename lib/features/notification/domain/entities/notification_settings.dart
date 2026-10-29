import 'package:meta/meta.dart';

/// Reminder preferences stored in `users/{uid}.notificationSettings` so the
/// hourly backend job can honor them (PLAN_02 §2.2).
@immutable
class NotificationSettings {
  /// Days before expiry the user can be alerted on.
  static const List<int> expiryAlertDayOptions = [1, 3, 7];

  /// ISO weekday: 1 = Monday ... 7 = Sunday.
  static const int defaultShoppingWeekday = DateTime.saturday;

  static const NotificationSettings defaults = NotificationSettings();

  final bool pushEnabled;
  final List<int> expiryAlertDays;

  /// Vietnam hour (0-23) for both expiry and weekly shopping reminders.
  final int reminderHour;
  final bool shoppingReminderEnabled;
  final int shoppingReminderWeekday;

  const NotificationSettings({
    this.pushEnabled = true,
    this.expiryAlertDays = const [1, 3],
    this.reminderHour = 8,
    this.shoppingReminderEnabled = true,
    this.shoppingReminderWeekday = defaultShoppingWeekday,
  });

  bool hasExpiryAlert(int days) => expiryAlertDays.contains(days);

  /// Returns a copy with [days] switched on or off, keeping the list sorted.
  NotificationSettings withExpiryAlert(int days, bool enabled) {
    final next = {...expiryAlertDays};
    if (enabled) {
      next.add(days);
    } else {
      next.remove(days);
    }
    return copyWith(expiryAlertDays: next.toList()..sort());
  }

  NotificationSettings copyWith({
    bool? pushEnabled,
    List<int>? expiryAlertDays,
    int? reminderHour,
    bool? shoppingReminderEnabled,
    int? shoppingReminderWeekday,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      expiryAlertDays: expiryAlertDays ?? this.expiryAlertDays,
      reminderHour: reminderHour ?? this.reminderHour,
      shoppingReminderEnabled:
          shoppingReminderEnabled ?? this.shoppingReminderEnabled,
      shoppingReminderWeekday:
          shoppingReminderWeekday ?? this.shoppingReminderWeekday,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.pushEnabled == pushEnabled &&
        _sameList(other.expiryAlertDays, expiryAlertDays) &&
        other.reminderHour == reminderHour &&
        other.shoppingReminderEnabled == shoppingReminderEnabled &&
        other.shoppingReminderWeekday == shoppingReminderWeekday;
  }

  @override
  int get hashCode => Object.hash(
    pushEnabled,
    Object.hashAll(expiryAlertDays),
    reminderHour,
    shoppingReminderEnabled,
    shoppingReminderWeekday,
  );

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
