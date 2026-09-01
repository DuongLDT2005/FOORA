import 'package:flutter/foundation.dart';
import 'package:foora/core/constants/app_enums.dart';

/// Pure domain entity representing a user device registration for push notifications.
/// Strictly mapped to users/{userId}/devices/{deviceId} in docs/DATABASE.md
@immutable
class Device {
  final String id;
  final String fcmToken;
  final AppPlatform platform;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Device({
    required this.id,
    required this.fcmToken,
    required this.platform,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device &&
        other.id == id &&
        other.fcmToken == fcmToken &&
        other.platform == platform &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, fcmToken, platform, isActive, createdAt, updatedAt);
}
