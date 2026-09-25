import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routes/app_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/services/notification_service.dart';

/// Builds the in-app location opened from an FCM payload.
///
/// The item form route accepts an [InventoryItem] extra, not an id, so a push
/// always lands on the notice list. The list resolves the item when it is
/// already loaded for the active household.
String notificationOpenLocation(Map<String, String> data) {
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

class PushOpenSource {
  final Future<RemoteMessage?> Function() getInitialMessage;
  final Stream<RemoteMessage> onMessageOpenedApp;

  const PushOpenSource({
    required this.getInitialMessage,
    required this.onMessageOpenedApp,
  });
}

final pushOpenSourceProvider = Provider<PushOpenSource>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return PushOpenSource(
    getInitialMessage: service.getInitialMessage,
    onMessageOpenedApp: service.onMessageOpenedApp,
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
  StreamSubscription<RemoteMessage>? _openedSub;

  @override
  void initState() {
    super.initState();
    final source = ref.read(pushOpenSourceProvider);
    source.getInitialMessage().then((message) {
      if (!mounted || message == null) {
        return;
      }
      _open(message);
    });
    _openedSub = source.onMessageOpenedApp.listen(_open);
  }

  @override
  void dispose() {
    _openedSub?.cancel();
    super.dispose();
  }

  void _open(RemoteMessage message) {
    final data = message.data.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    ref.read(routerProvider).push(notificationOpenLocation(data));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
