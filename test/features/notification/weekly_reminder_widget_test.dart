import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/services/local_notification_service.dart';
import 'package:foora/core/services/storage_service.dart';
import 'package:foora/features/auth/domain/entities/user.dart';
import 'package:foora/features/auth/presentation/providers/auth_provider.dart';
import 'package:foora/features/notification/domain/entities/weekly_reminder_config.dart';
import 'package:foora/features/notification/domain/repositories/weekly_reminder_repository.dart';
import 'package:foora/features/notification/presentation/providers/weekly_reminder_provider.dart';
import 'package:foora/features/notification/presentation/widgets/weekly_reminder_settings_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeWeeklyReminderRepo implements WeeklyReminderRepository {
  WeeklyReminderConfig config;
  bool permissionGranted;

  FakeWeeklyReminderRepo({
    this.config = const WeeklyReminderConfig(),
    this.permissionGranted = true,
  });

  @override
  Future<WeeklyReminderConfig> getConfig(String userId) async => config;

  @override
  Future<void> saveConfig(String userId, WeeklyReminderConfig newConfig) async {
    config = newConfig;
  }

  @override
  Future<void> scheduleReminder(WeeklyReminderConfig config) async {}

  @override
  Future<void> cancelReminder() async {}

  @override
  Future<bool> checkPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;
}

Widget _wrap(Widget child, {required List<dynamic> overrides}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) {
        return MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders disabled state initially with toggle switch (AT-01)', (tester) async {
    final fakeRepo = FakeWeeklyReminderRepo(
      config: const WeeklyReminderConfig(isEnabled: false),
    );

    await tester.pumpWidget(
      _wrap(
        const WeeklyReminderSettingsCard(),
        overrides: [
          weeklyReminderRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWith((ref) => User(
                id: 'u1',
                fullName: 'User 1',
                email: 'u1@test.com',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              )),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly Shopping Reminder'), findsOneWidget);
    expect(find.byKey(const Key('weekly_reminder_switch')), findsOneWidget);

    // Day & time selectors shouldn't be visible when disabled
    expect(find.byKey(const Key('weekly_reminder_day_selector')), findsNothing);
    expect(find.byKey(const Key('weekly_reminder_time_selector')), findsNothing);
  });

  testWidgets('shows day, time selectors and sample notification preview when enabled', (tester) async {
    final fakeRepo = FakeWeeklyReminderRepo(
      config: const WeeklyReminderConfig(
        isEnabled: true,
        dayOfWeek: DateTime.sunday,
        hour: 8,
        minute: 0,
      ),
    );

    await tester.pumpWidget(
      _wrap(
        const WeeklyReminderSettingsCard(),
        overrides: [
          weeklyReminderRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWith((ref) => User(
                id: 'u1',
                fullName: 'User 1',
                email: 'u1@test.com',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              )),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Check selectors
    expect(find.byKey(const Key('weekly_reminder_day_selector')), findsOneWidget);
    expect(find.byKey(const Key('weekly_reminder_time_selector')), findsOneWidget);
    expect(find.text('Chủ Nhật'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);

    // Check sample preview requirements (Section 5)
    expect(find.text('Mẫu thông báo khi đến lịch:'), findsOneWidget);
    expect(find.text('FOORA — Nhắc nhở mua sắm'), findsOneWidget);
    expect(find.text('Đến lúc kiểm tra danh sách mua sắm tuần này!'), findsOneWidget);
    expect(find.text('Chạm vào thông báo để mở nhanh Danh sách mua sắm.'), findsOneWidget);
    expect(find.text('Nhắc nhở vào Chủ Nhật lúc 08:00 mỗi tuần'), findsOneWidget);
  });

  testWidgets('displays warning banner when permission is missing (BR-05, AT-07)', (tester) async {
    final fakeRepo = FakeWeeklyReminderRepo(
      config: const WeeklyReminderConfig(isEnabled: true),
      permissionGranted: false,
    );

    await tester.pumpWidget(
      _wrap(
        const WeeklyReminderSettingsCard(),
        overrides: [
          weeklyReminderRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWith((ref) => User(
                id: 'u1',
                fullName: 'User 1',
                email: 'u1@test.com',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              )),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quyền thông báo chưa được cấp'), findsOneWidget);
    expect(find.text('Cấp quyền thông báo ngay'), findsOneWidget);
  });
}
