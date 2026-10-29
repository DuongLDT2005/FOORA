import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/helpers/debouncer.dart';
import '../../../notification/domain/entities/notification_settings.dart';
import '../../../notification/domain/repositories/notification_settings_repository.dart';
import '../../../notification/domain/usecases/save_notification_settings.dart';
import '../../../notification/domain/usecases/watch_notification_settings.dart';
import '../../../notification/presentation/providers/notification_provider.dart';

// --- State ---

@immutable
class NotificationSettingsState {
  final NotificationSettings settings;
  final bool soundEnabled;

  /// Set when the last save failed; the UI shows it once and clears it.
  final String? errorMessage;

  const NotificationSettingsState({
    this.settings = NotificationSettings.defaults,
    this.soundEnabled = true,
    this.errorMessage,
  });

  String get formattedReminderHour =>
      '${settings.reminderHour.toString().padLeft(2, '0')}:00';

  NotificationSettingsState copyWith({
    NotificationSettings? settings,
    bool? soundEnabled,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationSettingsState(
      settings: settings ?? this.settings,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Applies changes immediately, saves them to Firestore after a 500 ms pause
/// and rolls the UI back to the last synced value when the save fails.
class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsState> {
  final String? _userId;
  final NotificationSettingsRepository _repository;
  final SaveNotificationSettingsUseCase _saveUseCase;
  final Debouncer _debouncer;
  StreamSubscription<NotificationSettings?>? _subscription;

  NotificationSettings _lastSynced;
  bool _hasPendingEdit = false;

  NotificationSettingsNotifier({
    required String? userId,
    required NotificationSettingsRepository repository,
    required WatchNotificationSettingsUseCase watch,
    required SaveNotificationSettingsUseCase save,
    Duration saveDelay = const Duration(milliseconds: 500),
  }) : _userId = userId,
       _repository = repository,
       _saveUseCase = save,
       _debouncer = Debouncer(delay: saveDelay),
       _lastSynced =
           (userId == null ? null : repository.cached(userId)) ??
           repository.legacyLocalSettings(),
       super(const NotificationSettingsState()) {
    state = NotificationSettingsState(
      settings: _lastSynced,
      soundEnabled: repository.soundEnabled,
    );
    if (userId != null) {
      _subscription = watch(userId).listen((remote) {
        if (remote == null) return;
        _lastSynced = remote;
        if (!_hasPendingEdit) {
          state = state.copyWith(settings: remote);
        }
      }, onError: (_) {});
    }
  }

  void togglePush(bool value) =>
      _update(state.settings.copyWith(pushEnabled: value));

  void toggleExpiryAlert(int days, bool enabled) =>
      _update(state.settings.withExpiryAlert(days, enabled));

  void setReminderHour(int hour) =>
      _update(state.settings.copyWith(reminderHour: hour));

  void toggleShoppingReminder(bool value) =>
      _update(state.settings.copyWith(shoppingReminderEnabled: value));

  void setShoppingWeekday(int isoWeekday) =>
      _update(state.settings.copyWith(shoppingReminderWeekday: isoWeekday));

  Future<void> toggleSound(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await _repository.setSoundEnabled(value);
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _update(NotificationSettings next) {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(settings: next, clearError: true);
    _hasPendingEdit = true;
    _debouncer.run(() => _persist(userId, state.settings));
  }

  Future<void> _persist(String userId, NotificationSettings toSave) async {
    try {
      await _saveUseCase(userId, toSave);
      _lastSynced = toSave;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        settings: _lastSynced,
        errorMessage: 'Không lưu được cài đặt thông báo: $e',
      );
    } finally {
      _hasPendingEdit = false;
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _subscription?.cancel();
    // Leaving the page must not drop a change still waiting for the debounce.
    final userId = _userId;
    if (_hasPendingEdit && userId != null) {
      unawaited(_saveUseCase(userId, state.settings).catchError((_) {}));
    }
    super.dispose();
  }
}

final notificationSettingsProvider =
    StateNotifierProvider.autoDispose<
      NotificationSettingsNotifier,
      NotificationSettingsState
    >((ref) {
      final userId = ref.watch(currentNotificationUserIdProvider).valueOrNull;
      return NotificationSettingsNotifier(
        userId: userId,
        repository: ref.watch(notificationSettingsRepositoryProvider),
        watch: ref.watch(watchNotificationSettingsUseCaseProvider),
        save: ref.watch(saveNotificationSettingsUseCaseProvider),
      );
    });
