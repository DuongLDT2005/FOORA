import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/weekly_reminder_repository_impl.dart';
import '../../domain/entities/weekly_reminder_config.dart';
import '../../domain/repositories/weekly_reminder_repository.dart';

@immutable
class WeeklyReminderState {
  final WeeklyReminderConfig config;
  final bool hasNotificationPermission;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  const WeeklyReminderState({
    this.config = const WeeklyReminderConfig(),
    this.hasNotificationPermission = true,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  WeeklyReminderState copyWith({
    WeeklyReminderConfig? config,
    bool? hasNotificationPermission,
    bool? isLoading,
    String? errorMessage,
    String? infoMessage,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return WeeklyReminderState(
      config: config ?? this.config,
      hasNotificationPermission:
          hasNotificationPermission ?? this.hasNotificationPermission,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeeklyReminderState &&
        other.config == config &&
        other.hasNotificationPermission == hasNotificationPermission &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        other.infoMessage == infoMessage;
  }

  @override
  int get hashCode => Object.hash(
    config,
    hasNotificationPermission,
    isLoading,
    errorMessage,
    infoMessage,
  );
}

final weeklyReminderRepositoryProvider =
    Provider<WeeklyReminderRepository>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final notificationService = ref.watch(localNotificationServiceProvider);
      return WeeklyReminderRepositoryImpl(
        prefs: prefs,
        notificationService: notificationService,
      );
    });

class WeeklyReminderNotifier extends StateNotifier<WeeklyReminderState> {
  final WeeklyReminderRepository _repository;
  final Ref _ref;

  WeeklyReminderNotifier(this._repository, this._ref)
      : super(const WeeklyReminderState()) {
    _init();
  }

  String get _currentUserId {
    final user = _ref.read(currentUserProvider);
    return user?.id ?? '';
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final config = await _repository.getConfig(_currentUserId);
      final hasPerm = await _repository.checkPermission();
      state = state.copyWith(
        config: config,
        hasNotificationPermission: hasPerm,
        isLoading: false,
      );

      // BR-06: Check and sync on startup if enabled and permitted
      if (config.isEnabled && hasPerm) {
        await _repository.scheduleReminder(config);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Reload configuration when account changes (BR-01, BR-07)
  Future<void> loadForUser(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final config = await _repository.getConfig(userId);
      final hasPerm = await _repository.checkPermission();
      state = state.copyWith(
        config: config,
        hasNotificationPermission: hasPerm,
        isLoading: false,
      );
      if (config.isEnabled && hasPerm) {
        await _repository.scheduleReminder(config);
      } else {
        await _repository.cancelReminder();
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggle weekly shopping reminder on or off (FR-01, BR-02, BR-05, AT-01, AT-02, AT-04)
  Future<void> toggleReminder(bool enabled) async {
    final updatedConfig = state.config.copyWith(isEnabled: enabled);
    await _repository.saveConfig(_currentUserId, updatedConfig);

    if (enabled) {
      // Check permission before scheduling
      var hasPerm = await _repository.checkPermission();
      if (!hasPerm) {
        hasPerm = await _repository.requestPermission();
      }

      if (hasPerm) {
        await _repository.scheduleReminder(updatedConfig);
        state = state.copyWith(
          config: updatedConfig,
          hasNotificationPermission: true,
          clearError: true,
          infoMessage: 'Đã bật nhắc nhở mua sắm vào ${updatedConfig.dayNameVi} hàng tuần',
        );
      } else {
        // BR-05 & AT-07: Save config but do not schedule; prompt user to grant permission
        state = state.copyWith(
          config: updatedConfig,
          hasNotificationPermission: false,
          errorMessage:
              'Quyền thông báo chưa được cấp. Vui lòng cấp quyền trong cài đặt thiết bị.',
          clearInfo: true,
        );
      }
    } else {
      // BR-02 & AT-04: Disable and cancel upcoming notifications, retaining day and hour
      await _repository.cancelReminder();
      state = state.copyWith(
        config: updatedConfig,
        clearError: true,
        infoMessage: 'Đã tắt nhắc nhở mua sắm hàng tuần',
      );
    }
  }

  /// Update the day of the week (FR-02, FR-06, BR-03, AT-03)
  Future<void> setDayOfWeek(int dayOfWeek) async {
    final updatedConfig = state.config.copyWith(dayOfWeek: dayOfWeek);
    await _repository.saveConfig(_currentUserId, updatedConfig);

    if (updatedConfig.isEnabled && state.hasNotificationPermission) {
      // Replace existing schedule with new day (BR-03, AT-03)
      await _repository.scheduleReminder(updatedConfig);
    }

    state = state.copyWith(
      config: updatedConfig,
      clearError: true,
      infoMessage: 'Đã đổi ngày nhắc sang ${updatedConfig.dayNameVi}',
    );
  }

  /// Update the time of the reminder (FR-03, FR-06, BR-03, AT-03)
  Future<void> setReminderTime(int hour, int minute) async {
    final updatedConfig = state.config.copyWith(hour: hour, minute: minute);
    await _repository.saveConfig(_currentUserId, updatedConfig);

    if (updatedConfig.isEnabled && state.hasNotificationPermission) {
      // Replace existing schedule with new time (BR-03, AT-03)
      await _repository.scheduleReminder(updatedConfig);
    }

    state = state.copyWith(
      config: updatedConfig,
      clearError: true,
      infoMessage: 'Đã đổi giờ nhắc sang ${updatedConfig.formattedTime}',
    );
  }

  /// Request permission again if initially denied (BR-05)
  Future<void> requestPermission() async {
    final granted = await _repository.requestPermission();
    state = state.copyWith(hasNotificationPermission: granted);
    if (granted && state.config.isEnabled) {
      await _repository.scheduleReminder(state.config);
      state = state.copyWith(
        clearError: true,
        infoMessage: 'Đã cấp quyền thông báo và kích hoạt lịch nhắc',
      );
    }
  }

  /// Cancel reminder when user signs out (BR-07, AT-08)
  Future<void> cancelForLogout() async {
    await _repository.cancelReminder();
    state = const WeeklyReminderState();
  }

  /// Clear messages
  void clearMessages() {
    state = state.copyWith(clearError: true, clearInfo: true);
  }
}

final weeklyReminderProvider =
    StateNotifierProvider<WeeklyReminderNotifier, WeeklyReminderState>((ref) {
      final repository = ref.watch(weeklyReminderRepositoryProvider);
      final notifier = WeeklyReminderNotifier(repository, ref);

      // Listen to account changes to handle BR-01, BR-07, AT-08
      ref.listen<String?>(
        currentUserProvider.select((u) => u?.id),
        (previousUid, nextUid) {
          if (nextUid == null || nextUid.isEmpty) {
            notifier.cancelForLogout();
          } else if (previousUid != nextUid) {
            notifier.loadForUser(nextUid);
          }
        },
      );

      return notifier;
    });
