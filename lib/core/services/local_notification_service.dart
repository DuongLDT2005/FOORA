import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_logger.dart';

/// Provider for [LocalNotificationService].
final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
      final service = LocalNotificationServiceImpl();
      return service;
    });

/// Contract for local notification operations, enabling clean testing and abstraction.
abstract class LocalNotificationService {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> checkPermission();
  Future<void> scheduleWeeklyReminder({
    required int dayOfWeek,
    required int hour,
    required int minute,
    String? title,
    String? body,
  });
  Future<void> cancelWeeklyReminder();
  Stream<String> get onNotificationTapped;
}

class LocalNotificationServiceImpl implements LocalNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final StreamController<String> _tapStreamController =
      StreamController<String>.broadcast();

  bool _isInitialized = false;

  static const int weeklyShoppingNotificationId = 701;
  static const String weeklyShoppingPayload = '/shopping-lists';
  static const String defaultTitle = 'FOORA — Nhắc nhở mua sắm';
  static const String defaultBody = 'Đến lúc kiểm tra danh sách mua sắm tuần này!';

  static const String channelId = 'foora_weekly_shopping_channel';
  static const String channelName = 'Nhắc nhở mua sắm hàng tuần';
  static const String channelDescription =
      'Lịch thông báo nhắc nhở kiểm tra và mua sắm định kỳ mỗi tuần';

  LocalNotificationServiceImpl({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  @override
  Stream<String> get onNotificationTapped => _tapStreamController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      tz.initializeTimeZones();
      final String timeZoneName = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        // Fallback to local default offset if timezone name isn't directly in database
        final now = DateTime.now();
        final offset = now.timeZoneOffset;
        final location = tz.getLocation(
          tz.timeZoneDatabase.locations.keys.firstWhere(
            (k) => tz.getLocation(k).currentTimeZone.offset == offset,
            orElse: () => 'UTC',
          ),
        );
        tz.setLocalLocation(location);
      }
    } catch (e, st) {
      AppLogger.e('Failed to initialize timezone database', e, st);
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _tapStreamController.add(payload);
          }
        },
      );

      // Check cold-launch notification tap
      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          // Add a small delay to ensure listeners are registered
          Future.delayed(const Duration(milliseconds: 500), () {
            _tapStreamController.add(payload);
          });
        }
      }

      _isInitialized = true;
    } catch (e, st) {
      AppLogger.e('Failed to initialize FlutterLocalNotificationsPlugin', e, st);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } catch (e, st) {
        AppLogger.e('Error requesting Web notification permission', e, st);
        return true;
      }
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted =
            await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final iosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e, st) {
      AppLogger.e('Error requesting local notification permission', e, st);
      return false;
    }
  }

  @override
  Future<bool> checkPermission() async {
    if (kIsWeb) {
      try {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          return true;
        }
        return false;
      } catch (e, st) {
        AppLogger.e('Error checking Web notification permission', e, st);
        return true;
      }
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await androidImplementation?.areNotificationsEnabled() ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final iosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final permissions =
            await iosImplementation?.checkPermissions();
        return permissions?.isEnabled ?? false;
      }
      return true;
    } catch (e, st) {
      AppLogger.e('Error checking local notification permission', e, st);
      return false;
    }
  }

  /// Calculates the next instance of [dayOfWeek] (1=Monday... 7=Sunday) at [hour]:[minute].
  @visibleForTesting
  tz.TZDateTime nextInstanceOfWeekdayAndTime(
    int dayOfWeek,
    int hour,
    int minute, [
    tz.TZDateTime? baseTime,
  ]) {
    final now = baseTime ?? tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If day does not match or time has already passed today, advance day by day
    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  @override
  Future<void> scheduleWeeklyReminder({
    required int dayOfWeek,
    required int hour,
    required int minute,
    String? title,
    String? body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (kIsWeb) return;

    // Cancel existing reminder to avoid duplicate schedules (FR-06, BR-03, NFR-05)
    await cancelWeeklyReminder();

    final scheduledDate = nextInstanceOfWeekdayAndTime(dayOfWeek, hour, minute);

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: weeklyShoppingNotificationId,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title ?? defaultTitle,
        body: body ?? defaultBody,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: weeklyShoppingPayload,
      );
      AppLogger.d(
        'Successfully scheduled weekly reminder at: $scheduledDate (Day $dayOfWeek, $hour:$minute)',
      );
    } catch (e, st) {
      AppLogger.e('Failed to schedule weekly reminder', e, st);
      rethrow;
    }
  }

  @override
  Future<void> cancelWeeklyReminder() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id: weeklyShoppingNotificationId);
      AppLogger.d('Cancelled weekly shopping reminder ($weeklyShoppingNotificationId)');
    } catch (e, st) {
      AppLogger.e('Failed to cancel weekly shopping reminder', e, st);
    }
  }
}
