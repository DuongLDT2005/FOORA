import '../entities/notification_settings.dart';

/// Notification preferences synced to Firestore with a local offline cache.
abstract class NotificationSettingsRepository {
  /// Emits the stored settings, or null when the user has none yet.
  Stream<NotificationSettings?> watch(String userId);

  Future<void> save(String userId, NotificationSettings settings);

  /// Last settings cached on this device for [userId], if any.
  NotificationSettings? cached(String userId);

  /// Settings chosen on this device before they were synced (legacy prefs).
  NotificationSettings legacyLocalSettings();

  /// Notification sound only affects this device, so it stays local.
  bool get soundEnabled;
  Future<void> setSoundEnabled(bool value);
}
