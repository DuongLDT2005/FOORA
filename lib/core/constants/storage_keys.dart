class StorageKeys {
  StorageKeys._();

  static const String activeHouseholdId = 'active_household_id';
  static const String themeMode = 'theme_mode';
  static const String isFirstLaunch = 'is_first_launch';

  // Notification preferences. The `pref_notif_*` values were the only store
  // before PLAN_02; they are read once to seed the synced Firestore settings.
  static const String notificationSettingsCache = 'notif_settings_cache';
  static const String notificationSound = 'pref_notif_sound';
  static const String legacyNotificationPush = 'pref_notif_push';
  static const String legacyNotification1Day = 'pref_notif_1day';
  static const String legacyNotification3Days = 'pref_notif_3days';
  static const String legacyNotification7Days = 'pref_notif_7days';
  static const String legacyNotificationHour = 'pref_notif_hour';
}
