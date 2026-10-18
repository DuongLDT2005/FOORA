import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/app_notification.dart';

/// Data model for `users/{userId}/notifications/{id}`.
class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    super.householdId,
    super.type = NotificationType.system,
    required super.title,
    required super.message,
    super.inventoryItemId,
    super.isRead = false,
    required super.createdAt,
  });

  /// Builds a model from a Firestore snapshot.
  factory AppNotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AppNotificationModel.fromJson(data, id: doc.id);
  }

  /// Builds a model from a raw map.
  factory AppNotificationModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    return AppNotificationModel(
      id:
          id ??
          json['id'] as String? ??
          json['notificationId'] as String? ??
          '',
      householdId: json['householdId'] as String?,
      type: NotificationType.fromString(json['type'] as String?),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      inventoryItemId: json['inventoryItemId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  /// Serializes to a Firestore map.
  Map<String, dynamic> toFirestore() {
    return {
      if (householdId != null) 'householdId': householdId,
      'type': type.value,
      'title': title,
      'message': message,
      if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (householdId != null) 'householdId': householdId,
      'type': type.value,
      'title': title,
      'message': message,
      if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Accepts a Timestamp, ISO string or epoch millis; falls back to now.
  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }
}
