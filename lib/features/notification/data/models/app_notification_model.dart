import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/app_notification.dart';

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

  factory AppNotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AppNotificationModel.fromJson(data, id: doc.id);
  }

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
