import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/services/local_notification_service.dart';
import 'package:foora/core/services/storage_service.dart';
import 'package:foora/features/auth/domain/entities/user.dart';
import 'package:foora/features/auth/presentation/providers/auth_provider.dart';
import 'package:foora/features/notification/data/repositories/weekly_reminder_repository_impl.dart';
import 'package:foora/features/notification/domain/entities/weekly_reminder_config.dart';
import 'package:foora/features/notification/domain/repositories/weekly_reminder_repository.dart';
import 'package:foora/features/notification/presentation/providers/weekly_reminder_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLocalNotificationService implements LocalNotificationService {
  bool isInitialized = false;
  bool permissionGranted = true;
  int scheduleCount = 0;
  int cancelCount = 0;
  WeeklyReminderConfig? lastScheduledConfig;
  final StreamController<String> _tapController = StreamController<String>.broadcast();

  @override
  Stream<String> get onNotificationTapped => _tapController.stream;

  void simulateTap(String payload) {
    _tapController.add(payload);
  }

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    return permissionGranted;
  }

  @override
  Future<bool> checkPermission() async {
    return permissionGranted;
  }

  @override
  Future<void> scheduleWeeklyReminder({
    required int dayOfWeek,
    required int hour,
    required int minute,
    String? title,
    String? body,
  }) async {
    scheduleCount++;
    lastScheduledConfig = WeeklyReminderConfig(
      isEnabled: true,
      dayOfWeek: dayOfWeek,
      hour: hour,
      minute: minute,
    );
  }

  @override
  Future<void> cancelWeeklyReminder() async {
    cancelCount++;
    lastScheduledConfig = null;
  }

  void dispose() {
    _tapController.close();
  }
}

User _fakeUser(String id) => User(
      id: id,
      fullName: 'User $id',
      email: '$id@test.com',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('WeeklyReminderConfig Entity Tests', () {
    test('default constructor values conform to SRS (AT-01)', () {
      const config = WeeklyReminderConfig();
      expect(config.isEnabled, false);
      expect(config.dayOfWeek, DateTime.sunday);
      expect(config.hour, 8);
      expect(config.minute, 0);
      expect(config.dayNameVi, 'Chủ Nhật');
      expect(config.formattedTime, '08:00');
      expect(config.summaryText, 'Nhắc nhở vào Chủ Nhật lúc 08:00 mỗi tuần');
    });

    test('Vietnamese day names are formatted correctly for all 7 days (FR-02)', () {
      expect(const WeeklyReminderConfig(dayOfWeek: DateTime.monday).dayNameVi, 'Thứ Hai');
      expect(const WeeklyReminderConfig(dayOfWeek: DateTime.tuesday).dayNameVi, 'Thứ Ba');
      expect(const WeeklyReminderConfig(dayOfWeek: DateTime.wednesday).dayNameVi, 'Thứ Tư');
      expect(const WeeklyReminderConfig(dayOfWeek: DateTime.thursday).dayNameVi, 'Thứ Năm');
      expect(const WeeklyReminderConfig(dayOfWeek: DateTime.friday).dayNameVi, 'Thứ Sáu');
      expect(const WeeklyReminderConfig(dayOfWeek: DateTime.saturday).dayNameVi, 'Thứ Bảy');
      expect(const WeeklyReminderConfig(dayOfWeek: DateTime.sunday).dayNameVi, 'Chủ Nhật');
    });

    test('toJson and fromJson serialize and deserialize accurately', () {
      const original = WeeklyReminderConfig(
        isEnabled: true,
        dayOfWeek: DateTime.saturday,
        hour: 9,
        minute: 30,
      );
      final json = original.toJson();
      final fromJson = WeeklyReminderConfig.fromJson(json);

      expect(fromJson, original);
      expect(fromJson.dayNameVi, 'Thứ Bảy');
      expect(fromJson.formattedTime, '09:30');
    });
  });

  group('Weekly Reminder Acceptance Criteria (AT-01 to AT-08)', () {
    late SharedPreferences prefs;
    late MockLocalNotificationService mockNotificationService;
    late WeeklyReminderRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockNotificationService = MockLocalNotificationService();
      repository = WeeklyReminderRepositoryImpl(
        prefs: prefs,
        notificationService: mockNotificationService,
      );
    });

    tearDown(() {
      mockNotificationService.dispose();
    });

    test('AT-01: Default state is disabled for unconfigured account', () async {
      final config = await repository.getConfig('user_1');
      expect(config.isEnabled, isFalse);
    });

    test('AT-02: Enable with Sunday 08:00 and granted permission schedules weekly reminder', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localNotificationServiceProvider.overrideWithValue(mockNotificationService),
          currentUserProvider.overrideWith((ref) => _fakeUser('user_1')),
          weeklyReminderRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(weeklyReminderProvider.notifier);
      await pumpEventQueue();

      expect(container.read(weeklyReminderProvider).config.isEnabled, isFalse);

      // User toggles ON
      await notifier.toggleReminder(true);
      await pumpEventQueue();

      final state = container.read(weeklyReminderProvider);
      expect(state.config.isEnabled, isTrue);
      expect(state.hasNotificationPermission, isTrue);
      expect(mockNotificationService.scheduleCount, 1);
      expect(mockNotificationService.lastScheduledConfig?.dayOfWeek, DateTime.sunday);
      expect(mockNotificationService.lastScheduledConfig?.hour, 8);
      expect(mockNotificationService.lastScheduledConfig?.minute, 0);

      // Verify persisted in SharedPreferences
      final savedConfig = await repository.getConfig('user_1');
      expect(savedConfig.isEnabled, isTrue);
      expect(savedConfig.dayOfWeek, DateTime.sunday);
    });

    test('AT-03: Updating day/time replaces old schedule without creating duplicate', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localNotificationServiceProvider.overrideWithValue(mockNotificationService),
          currentUserProvider.overrideWith((ref) => _fakeUser('user_1')),
          weeklyReminderRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(weeklyReminderProvider.notifier);
      await pumpEventQueue();

      // Enable initially (Sunday 08:00)
      await notifier.toggleReminder(true);
      expect(mockNotificationService.scheduleCount, 1);

      // Change day to Saturday (Thứ Bảy)
      await notifier.setDayOfWeek(DateTime.saturday);
      expect(mockNotificationService.scheduleCount, 2);
      expect(mockNotificationService.lastScheduledConfig?.dayOfWeek, DateTime.saturday);

      // Change time to 09:30
      await notifier.setReminderTime(9, 30);
      expect(mockNotificationService.scheduleCount, 3);
      expect(mockNotificationService.lastScheduledConfig?.hour, 9);
      expect(mockNotificationService.lastScheduledConfig?.minute, 30);

      // Persisted check
      final savedConfig = await repository.getConfig('user_1');
      expect(savedConfig.dayOfWeek, DateTime.saturday);
      expect(savedConfig.hour, 9);
      expect(savedConfig.minute, 30);
    });

    test('AT-04: Disabling cancels scheduled notification but retains configured day and time (BR-02)', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localNotificationServiceProvider.overrideWithValue(mockNotificationService),
          currentUserProvider.overrideWith((ref) => _fakeUser('user_1')),
          weeklyReminderRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(weeklyReminderProvider.notifier);
      await pumpEventQueue();

      await notifier.toggleReminder(true);
      await notifier.setDayOfWeek(DateTime.friday);
      await notifier.setReminderTime(19, 45);

      // Toggle OFF
      await notifier.toggleReminder(false);
      await pumpEventQueue();

      expect(container.read(weeklyReminderProvider).config.isEnabled, isFalse);
      expect(mockNotificationService.cancelCount, greaterThanOrEqualTo(1));
      expect(mockNotificationService.lastScheduledConfig, isNull);

      // Check that preferences retained Friday 19:45
      final savedConfig = await repository.getConfig('user_1');
      expect(savedConfig.isEnabled, isFalse);
      expect(savedConfig.dayOfWeek, DateTime.friday);
      expect(savedConfig.hour, 19);
      expect(savedConfig.minute, 45);

      // Re-enable and verify previous day & time are restored
      await notifier.toggleReminder(true);
      final restoredConfig = container.read(weeklyReminderProvider).config;
      expect(restoredConfig.isEnabled, isTrue);
      expect(restoredConfig.dayOfWeek, DateTime.friday);
      expect(restoredConfig.hour, 19);
      expect(restoredConfig.minute, 45);
    });

    test('AT-05: Tapping notification triggers navigation payload to /shopping-lists', () async {
      final events = <String>[];
      final sub = mockNotificationService.onNotificationTapped.listen(events.add);

      mockNotificationService.simulateTap(LocalNotificationServiceImpl.weeklyShoppingPayload);
      await pumpEventQueue();

      expect(events, contains('/shopping-lists'));
      await sub.cancel();
    });

    test('AT-07: When permission is denied, config is saved as enabled but notification is not scheduled (BR-05)', () async {
      mockNotificationService.permissionGranted = false;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localNotificationServiceProvider.overrideWithValue(mockNotificationService),
          currentUserProvider.overrideWith((ref) => _fakeUser('user_denied')),
          weeklyReminderRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(weeklyReminderProvider.notifier);
      await pumpEventQueue();

      await notifier.toggleReminder(true);
      await pumpEventQueue();

      final state = container.read(weeklyReminderProvider);
      expect(state.config.isEnabled, isTrue);
      expect(state.hasNotificationPermission, isFalse);
      expect(state.errorMessage, isNotNull);
      // No notification scheduled without permission
      expect(mockNotificationService.scheduleCount, 0);

      // Config is saved nonetheless
      final saved = await repository.getConfig('user_denied');
      expect(saved.isEnabled, isTrue);
    });

    test('AT-08 & BR-07: Logout or switching account cancels old account reminder and loads new config', () async {
      final activeUser = StateProvider<User?>((ref) => _fakeUser('user_alpha'));

      // Pre-configure user_alpha as enabled and user_beta as disabled
      await repository.saveConfig(
        'user_alpha',
        const WeeklyReminderConfig(isEnabled: true, dayOfWeek: DateTime.tuesday, hour: 10, minute: 0),
      );
      await repository.saveConfig(
        'user_beta',
        const WeeklyReminderConfig(isEnabled: false, dayOfWeek: DateTime.saturday, hour: 14, minute: 0),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localNotificationServiceProvider.overrideWithValue(mockNotificationService),
          currentUserProvider.overrideWith((ref) => ref.watch(activeUser)),
          weeklyReminderRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // Keep notifier alive
      container.listen(weeklyReminderProvider, (_, _) {});
      await pumpEventQueue();

      // user_alpha is enabled -> scheduled
      expect(container.read(weeklyReminderProvider).config.isEnabled, isTrue);
      expect(container.read(weeklyReminderProvider).config.dayOfWeek, DateTime.tuesday);

      // Logout (activeUser becomes null)
      container.read(activeUser.notifier).state = null;
      await pumpEventQueue();

      // Notification must be cancelled for old account
      expect(mockNotificationService.lastScheduledConfig, isNull);

      // Login as user_beta
      container.read(activeUser.notifier).state = _fakeUser('user_beta');
      await pumpEventQueue();

      // user_beta config loaded
      final betaConfig = container.read(weeklyReminderProvider).config;
      expect(betaConfig.isEnabled, isFalse);
      expect(betaConfig.dayOfWeek, DateTime.saturday);
    });
  });
}
