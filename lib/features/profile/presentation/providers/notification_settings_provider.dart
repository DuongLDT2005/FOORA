import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/storage_service.dart';

@immutable
class NotificationSettingsState {
  final bool isPushEnabled;
  final bool expiryAlert1Day;
  final bool expiryAlert3Days;
  final bool expiryAlert7Days;
  final int reminderHour;
  final int reminderMinute;
  final bool soundEnabled;

  const NotificationSettingsState({
    this.isPushEnabled = true,
    this.expiryAlert1Day = true,
    this.expiryAlert3Days = true,
    this.expiryAlert7Days = false,
    this.reminderHour = 8,
    this.reminderMinute = 0,
    this.soundEnabled = true,
  });

  String get formattedReminderTime {
    final h = reminderHour.toString().padLeft(2, '0');
    final m = reminderMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  NotificationSettingsState copyWith({
    bool? isPushEnabled,
    bool? expiryAlert1Day,
    bool? expiryAlert3Days,
    bool? expiryAlert7Days,
    int? reminderHour,
    int? reminderMinute,
    bool? soundEnabled,
  }) {
    return NotificationSettingsState(
      isPushEnabled: isPushEnabled ?? this.isPushEnabled,
      expiryAlert1Day: expiryAlert1Day ?? this.expiryAlert1Day,
      expiryAlert3Days: expiryAlert3Days ?? this.expiryAlert3Days,
      expiryAlert7Days: expiryAlert7Days ?? this.expiryAlert7Days,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsState> {
  final SharedPreferences _prefs;

  static const String _keyPush = 'pref_notif_push';
  static const String _key1Day = 'pref_notif_1day';
  static const String _key3Days = 'pref_notif_3days';
  static const String _key7Days = 'pref_notif_7days';
  static const String _keyHour = 'pref_notif_hour';
  static const String _keyMinute = 'pref_notif_minute';
  static const String _keySound = 'pref_notif_sound';

  NotificationSettingsNotifier(this._prefs)
    : super(
        NotificationSettingsState(
          isPushEnabled: _prefs.getBool(_keyPush) ?? true,
          expiryAlert1Day: _prefs.getBool(_key1Day) ?? true,
          expiryAlert3Days: _prefs.getBool(_key3Days) ?? true,
          expiryAlert7Days: _prefs.getBool(_key7Days) ?? false,
          reminderHour: _prefs.getInt(_keyHour) ?? 8,
          reminderMinute: _prefs.getInt(_keyMinute) ?? 0,
          soundEnabled: _prefs.getBool(_keySound) ?? true,
        ),
      );

  Future<void> togglePush(bool value) async {
    state = state.copyWith(isPushEnabled: value);
    await _prefs.setBool(_keyPush, value);
  }

  Future<void> toggleExpiry1Day(bool value) async {
    state = state.copyWith(expiryAlert1Day: value);
    await _prefs.setBool(_key1Day, value);
  }

  Future<void> toggleExpiry3Days(bool value) async {
    state = state.copyWith(expiryAlert3Days: value);
    await _prefs.setBool(_key3Days, value);
  }

  Future<void> toggleExpiry7Days(bool value) async {
    state = state.copyWith(expiryAlert7Days: value);
    await _prefs.setBool(_key7Days, value);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
    await _prefs.setInt(_keyHour, hour);
    await _prefs.setInt(_keyMinute, minute);
  }

  Future<void> toggleSound(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await _prefs.setBool(_keySound, value);
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<
      NotificationSettingsNotifier,
      NotificationSettingsState
    >((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return NotificationSettingsNotifier(prefs);
    });
