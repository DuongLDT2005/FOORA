import '../repositories/notification_settings_repository.dart';

/// Writes default settings (merged with this device's legacy preferences)
/// when the user document has none, so the backend job can find every active
/// user (PLAN_02 §4.2).
class EnsureNotificationSettingsUseCase {
  final NotificationSettingsRepository _repository;

  const EnsureNotificationSettingsUseCase(this._repository);

  Future<void> call(String userId) async {
    final current = await _repository.watch(userId).first;
    if (current != null) return;
    await _repository.save(userId, _repository.legacyLocalSettings());
  }
}
