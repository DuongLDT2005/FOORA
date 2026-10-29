import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../utils/app_logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.d('FCM background message: ${message.messageId}');
}

/// Must match the `channelId` the Cloud Functions send and the
/// `default_notification_channel_id` in AndroidManifest.xml.
const AndroidNotificationChannel fooraNotificationChannel =
    AndroidNotificationChannel(
      'foora_notifications',
      'Thông báo FOORA',
      description: 'Nhắc hạn sử dụng, mua sắm và hoạt động của gia đình',
      importance: Importance.high,
    );

const String _androidNotificationIcon = 'ic_notification';

/// Logo green; matches `notification_accent` in the Android resources.
const Color _notificationAccent = Color(0xFF70AA44);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final messaging = ref.watch(messagingProvider);
  return NotificationService(messaging, LocalNotificationPresenter.instance);
});

/// Shows FCM pushes that arrive while the app is in the foreground, where
/// Android does not display them on its own. Pushes received in background
/// are drawn by the system using the same channel and icon.
class LocalNotificationPresenter {
  LocalNotificationPresenter._();

  static final LocalNotificationPresenter instance =
      LocalNotificationPresenter._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, String>> _taps =
      StreamController<Map<String, String>>.broadcast();
  bool _initialized = false;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Data payloads of foreground notifications the user taps.
  Stream<Map<String, String>> get onTap => _taps.stream;

  /// Creates the channel and starts presenting foreground pushes. Safe to call
  /// more than once.
  Future<void> initialize() async {
    if (!_supported || _initialized) {
      return;
    }
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_androidNotificationIcon),
        ),
        onDidReceiveNotificationResponse: (response) {
          final data = _decode(response.payload);
          if (data != null) {
            _taps.add(data);
          }
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(fooraNotificationChannel);
      FirebaseMessaging.onMessage.listen(show);
    } catch (e, st) {
      _initialized = false;
      AppLogger.e('Could not initialize local notifications', e, st);
    }
  }

  Future<void> show(RemoteMessage message) async {
    final notification = message.notification;
    if (!_initialized || notification == null) {
      return;
    }
    try {
      await _plugin.show(
        id: message.messageId?.hashCode ?? notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            fooraNotificationChannel.id,
            fooraNotificationChannel.name,
            channelDescription: fooraNotificationChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: _androidNotificationIcon,
            color: _notificationAccent,
            styleInformation: BigTextStyleInformation(notification.body ?? ''),
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (e, st) {
      AppLogger.e('Could not show foreground notification', e, st);
    }
  }

  /// Data payload of the foreground notification that launched the app, if
  /// the app was killed after it was shown.
  Future<Map<String, String>?> getLaunchData() async {
    if (!_initialized) {
      return null;
    }
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    return _decode(details.notificationResponse?.payload);
  }

  static Map<String, String>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return null;
    }
  }
}

class NotificationService {
  final FirebaseMessaging _messaging;
  final LocalNotificationPresenter _presenter;

  NotificationService(this._messaging, this._presenter);

  Future<NotificationSettings> requestPermission() async {
    return await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e, st) {
      AppLogger.e('Error getting FCM token', e, st);
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Data payload of the notification that launched the app, if any: a
  /// system-drawn push first, then a foreground one shown by the presenter.
  Future<Map<String, String>?> getInitialMessageData() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      return _stringify(message.data);
    }
    return _presenter.getLaunchData();
  }

  /// Data payloads of notifications the user taps while the app is running,
  /// whether the system or the presenter drew them.
  Stream<Map<String, String>> get onMessageOpenedAppData {
    late final StreamController<Map<String, String>> controller;
    final subs = <StreamSubscription<Map<String, String>>>[];
    controller = StreamController<Map<String, String>>(
      onListen: () {
        subs
          ..add(
            FirebaseMessaging.onMessageOpenedApp
                .map((m) => _stringify(m.data))
                .listen(controller.add, onError: controller.addError),
          )
          ..add(
            _presenter.onTap.listen(
              controller.add,
              onError: controller.addError,
            ),
          );
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }

  static Map<String, String> _stringify(Map<String, dynamic> data) =>
      data.map((key, value) => MapEntry(key, value.toString()));
}
