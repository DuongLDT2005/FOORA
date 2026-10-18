import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/app_notification_model.dart';
import '../models/device_model.dart';

/// Contract for push-notification devices and the in-app notification inbox.
abstract class NotificationRemoteDataSource {
  /// Registers this device's FCM token so the server can send push messages.
  Future<void> registerDevice(String userId);

  /// Removes this device's token (called on logout).
  Future<void> unregisterDevice(String userId);

  /// Real-time stream of the user's notifications, newest first.
  Stream<List<AppNotificationModel>> getNotifications(String userId);

  /// Marks one notification as read.
  Future<void> markAsRead(String userId, String notificationId);

  /// Marks every unread notification as read.
  Future<void> markAllAsRead(String userId);
}

/// Firebase Messaging + Firestore implementation of [NotificationRemoteDataSource].
class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseMessaging messaging;
  final SharedPreferences sharedPreferences;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentRegisteredUserId;

  static const String _deviceIdPrefKey = 'foora_device_installation_id';

  NotificationRemoteDataSourceImpl({
    required this.firestore,
    required this.messaging,
    required this.sharedPreferences,
  });

  /// Returns a persistent unique device ID for this installation
  String _getOrCreateDeviceId() {
    String? deviceId = sharedPreferences.getString(_deviceIdPrefKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId =
          'device_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      sharedPreferences.setString(_deviceIdPrefKey, deviceId);
    }
    return deviceId;
  }

  /// Platform mapping strictly adhering to docs/DATABASE.md ('android' or 'ios')
  AppPlatform _resolvePlatform() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppPlatform.ios;
    }
    return AppPlatform.android;
  }

  /// Requests permission, gets the FCM token and stores it under
  /// `users/{userId}/devices/{deviceId}`; also listens for token refreshes.
  @override
  Future<void> registerDevice(String userId) async {
    if (userId.isEmpty) return;
    _currentRegisteredUserId = userId;

    try {
      // 1. Request user permission for notifications
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.w('Notification permission denied.');
        return;
      }

      // 2. Fetch current FCM token
      final fcmToken = await messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        AppLogger.w('FCM token is null or empty.');
        return;
      }

      final deviceId = _getOrCreateDeviceId();
      final platform = _resolvePlatform();
      final now = DateTime.now();

      final deviceModel = DeviceModel(
        id: deviceId,
        fcmToken: fcmToken,
        platform: platform,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // 3. Save / merge to users/{userId}/devices/{deviceId}
      await firestore
          .collection(FirestoreConstants.users)
          .doc(userId)
          .collection(FirestoreConstants.devices)
          .doc(deviceId)
          .set(deviceModel.toFirestore(), SetOptions(merge: true));

      AppLogger.i('Registered device $deviceId for user $userId.');

      // 4. Auto-update token on refresh
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
        if (_currentRegisteredUserId != null && newToken.isNotEmpty) {
          final refreshedDeviceId = _getOrCreateDeviceId();
          firestore
              .collection(FirestoreConstants.users)
              .doc(_currentRegisteredUserId)
              .collection(FirestoreConstants.devices)
              .doc(refreshedDeviceId)
              .update({
                'fcmToken': newToken,
                'updatedAt': FieldValue.serverTimestamp(),
              })
              .catchError((e) {
                AppLogger.e('Token refresh update failed.', e);
              });
        }
      });
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Deletes the device document and the local FCM token.
  @override
  Future<void> unregisterDevice(String userId) async {
    if (userId.isEmpty) return;

    try {
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _currentRegisteredUserId = null;

      final deviceId = _getOrCreateDeviceId();
      final deviceRef = firestore
          .collection(FirestoreConstants.users)
          .doc(userId)
          .collection(FirestoreConstants.devices)
          .doc(deviceId);

      final doc = await deviceRef.get();
      if (doc.exists) {
        await deviceRef.update({
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      AppLogger.i('Unregistered device $deviceId for user $userId.');
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Listens to `users/{userId}/notifications` ordered by creation time.
  @override
  Stream<List<AppNotificationModel>> getNotifications(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    return firestore
        .collection(FirestoreConstants.users)
        .doc(userId)
        .collection(FirestoreConstants.notifications)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppNotificationModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Sets `isRead = true` on a single notification.
  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await firestore
          .collection(FirestoreConstants.users)
          .doc(userId)
          .collection(FirestoreConstants.notifications)
          .doc(notificationId)
          .update({'isRead': true});
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Batch-updates all unread notifications to read.
  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      final unreadDocs = await firestore
          .collection(FirestoreConstants.users)
          .doc(userId)
          .collection(FirestoreConstants.notifications)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isEmpty) return;

      final batch = firestore.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
