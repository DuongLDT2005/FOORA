import 'package:flutter/material.dart';

/// Configuration for the Weekly Shopping Reminder feature (MVP).
///
/// Implements FR-01, FR-02, FR-03 and BR-01.
@immutable
class WeeklyReminderConfig {
  /// Whether weekly shopping reminders are enabled. Default is false (AT-01).
  final bool isEnabled;

  /// Day of the week: 1 = Monday (Thứ Hai), ..., 7 = Sunday (Chủ Nhật).
  /// Aligns with [DateTime.monday] through [DateTime.sunday].
  final int dayOfWeek;

  /// Hour in 24h format (0 - 23) in device's local timezone.
  final int hour;

  /// Minute (0 - 59).
  final int minute;

  const WeeklyReminderConfig({
    this.isEnabled = false,
    this.dayOfWeek = DateTime.sunday,
    this.hour = 8,
    this.minute = 0,
  });

  /// Vietnamese label for [dayOfWeek].
  String get dayNameVi {
    switch (dayOfWeek) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
      default:
        return 'Chủ Nhật';
    }
  }

  /// Formatted time in 'HH:mm' format.
  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Human-readable schedule summary.
  String get summaryText {
    return 'Nhắc nhở vào $dayNameVi lúc $formattedTime mỗi tuần';
  }

  WeeklyReminderConfig copyWith({
    bool? isEnabled,
    int? dayOfWeek,
    int? hour,
    int? minute,
  }) {
    return WeeklyReminderConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'dayOfWeek': dayOfWeek,
      'hour': hour,
      'minute': minute,
    };
  }

  factory WeeklyReminderConfig.fromJson(Map<String, dynamic> json) {
    return WeeklyReminderConfig(
      isEnabled: json['isEnabled'] as bool? ?? false,
      dayOfWeek: json['dayOfWeek'] as int? ?? DateTime.sunday,
      hour: json['hour'] as int? ?? 8,
      minute: json['minute'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeeklyReminderConfig &&
        other.isEnabled == isEnabled &&
        other.dayOfWeek == dayOfWeek &&
        other.hour == hour &&
        other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(isEnabled, dayOfWeek, hour, minute);

  @override
  String toString() =>
      'WeeklyReminderConfig(isEnabled: $isEnabled, day: $dayOfWeek ($dayNameVi), time: $formattedTime)';
}
