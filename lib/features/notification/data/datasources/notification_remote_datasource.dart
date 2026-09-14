import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/app_notification_model.dart';
import '../models/device_model.dart';

abstract class NotificationRemoteDataSource {
  Future<void> registerDevice(String userId);
  Future<void> unregisterDevice(String userId);
  Stream<List<AppNotificationModel>> getNotifications(String userId);
  Future<void> markAsRead(String userId, String notificationId);
  Future<void> markAllAsRead(String userId);
}

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
        if (kDebugMode) {
          print('⚠️ [NotificationDataSource] Notification permission denied.');
        }
        return;
      }

      // 2. Fetch current FCM token
      final fcmToken = await messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) {
          print('⚠️ [NotificationDataSource] FCM token is null or empty.');
        }
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

      if (kDebugMode) {
        print(
          '✅ [NotificationDataSource] Registered device $deviceId for user $userId',
        );
      }

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
                if (kDebugMode) {
                  print(
                    '❌ [NotificationDataSource] Token refresh update failed: $e',
                  );
                }
              });
        }
      });
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

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

      if (kDebugMode) {
        print(
          '🔒 [NotificationDataSource] Unregistered device $deviceId for user $userId',
        );
      }
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

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
