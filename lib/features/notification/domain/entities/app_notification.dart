import 'package:flutter/foundation.dart';
import 'package:foora/core/constants/app_enums.dart';

/// Pure domain entity representing an in-app notification.
/// Strictly mapped to users/{userId}/notifications/{notificationId} in docs/DATABASE.md
@immutable
class AppNotification {
  final String id;
  final String? householdId;
  final NotificationType type;
  final String title;
  final String message;
  final String? inventoryItemId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    this.householdId,
    required this.type,
    required this.title,
    required this.message,
    this.inventoryItemId,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    String? householdId,
    NotificationType? type,
    String? title,
    String? message,
    String? inventoryItemId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification &&
        other.id == id &&
        other.householdId == householdId &&
        other.type == type &&
        other.title == title &&
        other.message == message &&
        other.inventoryItemId == inventoryItemId &&
        other.isRead == isRead &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    householdId,
    type,
    title,
    message,
    inventoryItemId,
    isRead,
    createdAt,
  );
}
