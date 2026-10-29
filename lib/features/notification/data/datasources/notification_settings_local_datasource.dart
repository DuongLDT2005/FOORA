import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/notification_settings.dart';
import '../models/notification_settings_model.dart';

/// Device-local storage: an offline cache of the synced settings, the
/// pre-sync (legacy) preferences, and the device-only sound switch.
class NotificationSettingsLocalDataSource {
  final SharedPreferences prefs;

  const NotificationSettingsLocalDataSource({required this.prefs});

  String _cacheKey(String userId) =>
      '${StorageKeys.notificationSettingsCache}_$userId';

  NotificationSettings? readCache(String userId) {
    final raw = prefs.getString(_cacheKey(userId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? NotificationSettingsModel.fromMap(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeCache(String userId, NotificationSettings settings) {
    return prefs.setString(
      _cacheKey(userId),
      jsonEncode(NotificationSettingsModel.toMap(settings)),
    );
  }

  /// Maps the old `pref_notif_*` switches to the synced shape (PLAN_02 §4.1).
  NotificationSettings readLegacy() {
    const d = NotificationSettings.defaults;
    final days = <int>[
      if (prefs.getBool(StorageKeys.legacyNotification1Day) ?? true) 1,
      if (prefs.getBool(StorageKeys.legacyNotification3Days) ?? true) 3,
      if (prefs.getBool(StorageKeys.legacyNotification7Days) ?? false) 7,
    ];
    final hour = prefs.getInt(StorageKeys.legacyNotificationHour);
    return d.copyWith(
      pushEnabled: prefs.getBool(StorageKeys.legacyNotificationPush),
      expiryAlertDays: days,
      reminderHour: hour != null && hour >= 0 && hour <= 23 ? hour : null,
    );
  }

  bool get soundEnabled => prefs.getBool(StorageKeys.notificationSound) ?? true;

  Future<void> setSoundEnabled(bool value) =>
      prefs.setBool(StorageKeys.notificationSound, value);
}
