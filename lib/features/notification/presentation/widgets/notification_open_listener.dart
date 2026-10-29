import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../providers/notification_provider.dart';

/// Builds the in-app location opened from an FCM payload.
///
/// A weekly shopping reminder opens the shopping lists. The item form route
/// accepts an [InventoryItem] extra, not an id, so other pushes land on the
/// notice list, which resolves the item when it is already loaded for the
/// active household.
String notificationOpenLocation(Map<String, String> data) {
  if (data['type'] == NotificationType.shoppingReminder.value) {
    return AppRouteNames.shoppingLists;
  }
  final params = <String, String>{};
  final itemId = data['inventoryItemId'] ?? '';
  final householdId = data['householdId'] ?? '';
  if (itemId.isNotEmpty) {
    params['inventoryItemId'] = itemId;
  }
  if (householdId.isNotEmpty) {
    params['householdId'] = householdId;
  }
  return Uri(
    path: AppRouteNames.notifications,
    queryParameters: params.isEmpty ? null : params,
  ).toString();
}

/// Push-open events as plain data payloads, so the UI never touches the
/// Firebase Messaging SDK directly.
class PushOpenSource {
  final Future<Map<String, String>?> Function() getInitialMessage;
  final Stream<Map<String, String>> onMessageOpenedApp;

  const PushOpenSource({
    required this.getInitialMessage,
    required this.onMessageOpenedApp,
  });
}

final pushOpenSourceProvider = Provider<PushOpenSource>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return PushOpenSource(
    getInitialMessage: service.getInitialMessageData,
    onMessageOpenedApp: service.onMessageOpenedAppData,
  );
});

class NotificationOpenListener extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationOpenListener({super.key, required this.child});

  @override
  ConsumerState<NotificationOpenListener> createState() =>
      _NotificationOpenListenerState();
}

class _NotificationOpenListenerState
    extends ConsumerState<NotificationOpenListener> {
  StreamSubscription<Map<String, String>>? _openedSub;

  @override
  void initState() {
    super.initState();
    final source = ref.read(pushOpenSourceProvider);
    source
        .getInitialMessage()
        .then((data) {
          if (!mounted || data == null) {
            return;
          }
          _open(data);
        })
        .catchError((Object e, StackTrace st) {
          AppLogger.e('Could not read the launching push message', e, st);
        });
    _openedSub = source.onMessageOpenedApp.listen(_open);

    // Every signed-in user needs `notificationSettings` so the hourly backend
    // reminder job can find them (PLAN_02 §4.2).
    ref.listenManual<AsyncValue<String?>>(currentNotificationUserIdProvider, (
      _,
      next,
    ) {
      final userId = next.valueOrNull;
      if (userId == null) return;
      ref.read(ensureNotificationSettingsUseCaseProvider)(userId).catchError((
        Object e,
        StackTrace st,
      ) {
        AppLogger.e('Could not initialize notification settings', e, st);
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _openedSub?.cancel();
    super.dispose();
  }

  void _open(Map<String, String> data) {
    ref.read(routerProvider).push(notificationOpenLocation(data));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
