import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/storage_keys.dart';
import 'package:foora/features/notification/data/datasources/notification_settings_local_datasource.dart';
import 'package:foora/features/notification/data/models/notification_settings_model.dart';
import 'package:foora/features/notification/domain/entities/notification_settings.dart';
import 'package:foora/features/notification/domain/repositories/notification_settings_repository.dart';
import 'package:foora/features/notification/domain/usecases/ensure_notification_settings.dart';
import 'package:foora/features/notification/presentation/providers/notification_provider.dart';
import 'package:foora/features/notification/presentation/widgets/notification_open_listener.dart';
import 'package:foora/features/profile/presentation/pages/notification_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy device preferences map to the synced settings', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.legacyNotificationPush: false,
      StorageKeys.legacyNotification1Day: false,
      StorageKeys.legacyNotification3Days: true,
      StorageKeys.legacyNotification7Days: true,
      StorageKeys.legacyNotificationHour: 20,
    });
    final local = NotificationSettingsLocalDataSource(
      prefs: await SharedPreferences.getInstance(),
    );

    final settings = local.readLegacy();

    expect(settings.pushEnabled, isFalse);
    expect(settings.expiryAlertDays, [3, 7]);
    expect(settings.reminderHour, 20);
    expect(settings.shoppingReminderEnabled, isTrue);
    expect(settings.shoppingReminderWeekday, DateTime.saturday);
  });

  test('model falls back field by field and keeps integers', () {
    final parsed = NotificationSettingsModel.fromMap({
      'pushEnabled': 'yes',
      'expiryAlertDays': [7, 2, 1, 7],
      'reminderHour': 30,
      'shoppingReminderWeekday': 2,
    });

    expect(parsed.pushEnabled, isTrue);
    expect(parsed.expiryAlertDays, [1, 7]);
    expect(parsed.reminderHour, 8);
    expect(parsed.shoppingReminderWeekday, 2);
    expect(
      NotificationSettingsModel.toMap(parsed)['shoppingReminderWeekday'],
      isA<int>(),
    );
  });

  test('defaults are written only when the user has no settings', () async {
    final repo = _FakeSettingsRepository(remote: null);
    await EnsureNotificationSettingsUseCase(repo)('user-1');
    expect(repo.saved, [repo.legacyLocalSettings()]);

    final existing = _FakeSettingsRepository(
      remote: const NotificationSettings(reminderHour: 6),
    );
    await EnsureNotificationSettingsUseCase(existing)('user-1');
    expect(existing.saved, isEmpty);
  });

  test('shopping reminder pushes open the shopping lists', () {
    expect(
      notificationOpenLocation({'type': 'shopping_reminder'}),
      '/shopping-lists',
    );
  });

  testWidgets('choosing Saturday saves shoppingReminderWeekday 6', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeSettingsRepository(
      remote: const NotificationSettings(shoppingReminderWeekday: 1),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationSettingsRepositoryProvider.overrideWithValue(repo),
          currentNotificationUserIdProvider.overrideWith(
            (ref) => Stream.value('user-1'),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) =>
              const MaterialApp(home: NotificationSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Thứ Hai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thứ Hai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thứ Bảy').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    expect(repo.saved.last.shoppingReminderWeekday, 6);
  });
}

class _FakeSettingsRepository implements NotificationSettingsRepository {
  final NotificationSettings? remote;
  final List<NotificationSettings> saved = [];

  _FakeSettingsRepository({required this.remote});

  @override
  Stream<NotificationSettings?> watch(String userId) => Stream.value(remote);

  @override
  Future<void> save(String userId, NotificationSettings settings) async {
    saved.add(settings);
  }

  @override
  NotificationSettings? cached(String userId) => remote;

  @override
  NotificationSettings legacyLocalSettings() =>
      const NotificationSettings(reminderHour: 19);

  @override
  bool get soundEnabled => true;

  @override
  Future<void> setSoundEnabled(bool value) async {}
}
