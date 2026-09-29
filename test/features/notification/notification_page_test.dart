import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/notification/domain/entities/app_notification.dart';
import 'package:foora/features/notification/presentation/pages/notification_page.dart';
import 'package:foora/features/notification/presentation/providers/notification_provider.dart';
import 'package:foora/features/notification/presentation/widgets/notification_open_listener.dart';
import 'package:foora/features/notification/presentation/widgets/notification_tile.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('push open location stays on the notice list', () {
    expect(
      notificationOpenLocation({
        'inventoryItemId': 'item-1',
        'householdId': 'home-1',
      }),
      '/notifications?inventoryItemId=item-1&householdId=home-1',
    );
    expect(notificationOpenLocation({}), '/notifications');
  });

  testWidgets('unread notice shows the unread marker and mark-all action', (
    tester,
  ) async {
    await _pumpInbox(tester, [_notification(id: 'n1', isRead: false)]);

    expect(find.text('Sữa tươi sắp hết hạn'), findsOneWidget);
    expect(find.byKey(const Key('notification-unread-dot')), findsOneWidget);
    expect(find.text('Đã đọc hết'), findsOneWidget);
  });

  testWidgets('read notice hides the unread marker', (tester) async {
    await _pumpInbox(tester, [_notification(id: 'n1', isRead: true)]);

    expect(find.text('Sữa tươi sắp hết hạn'), findsOneWidget);
    expect(find.byKey(const Key('notification-unread-dot')), findsNothing);
    expect(find.text('Đã đọc hết'), findsNothing);
  });

  testWidgets('empty inbox shows the empty state', (tester) async {
    await _pumpInbox(tester, const []);

    expect(find.text('Chưa có thông báo nào'), findsOneWidget);
    expect(find.byType(NotificationTile), findsNothing);
  });

  testWidgets('failed inbox shows an error state with retry', (tester) async {
    await _pumpPage(
      tester,
      notifications: Stream<List<AppNotification>>.error(Exception('offline')),
    );

    expect(find.text('Đã xảy ra lỗi'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('loading inbox shows the loading message', (tester) async {
    final pending = StreamController<List<AppNotification>>();
    addTearDown(pending.close);

    await _pumpPage(tester, notifications: pending.stream);
    await tester.pump();

    expect(find.text('Đang tải thông báo...'), findsOneWidget);
  });
}

AppNotification _notification({required String id, required bool isRead}) {
  return AppNotification(
    id: id,
    householdId: 'home-1',
    type: NotificationType.upcomingExpiration,
    title: 'Sữa tươi sắp hết hạn',
    message: 'Sữa tươi sẽ hết hạn trong 2 ngày.',
    inventoryItemId: 'item-1',
    isRead: isRead,
    createdAt: DateTime.utc(2026, 9, 25),
  );
}

Future<void> _pumpInbox(
  WidgetTester tester,
  List<AppNotification> notifications,
) {
  return _pumpPage(tester, notifications: Stream.value(notifications));
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Stream<List<AppNotification>> notifications,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentNotificationUserIdProvider.overrideWith(
          (ref) => Stream.value('user-1'),
        ),
        userNotificationsStreamProvider.overrideWith(
          (ref, userId) => notifications,
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
