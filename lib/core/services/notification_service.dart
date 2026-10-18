import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../utils/app_logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.d('FCM background message: ${message.messageId}');
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final messaging = ref.watch(messagingProvider);
  return NotificationService(messaging);
});

class NotificationService {
  final FirebaseMessaging _messaging;

  NotificationService(this._messaging);

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

  /// Data payload of the push that launched the app, if any.
  Future<Map<String, String>?> getInitialMessageData() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _stringify(message.data);
  }

  /// Data payloads of pushes the user taps while the app is in background.
  Stream<Map<String, String>> get onMessageOpenedAppData =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => _stringify(m.data));

  static Map<String, String> _stringify(Map<String, dynamic> data) =>
      data.map((key, value) => MapEntry(key, value.toString()));
}
