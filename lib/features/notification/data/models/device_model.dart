import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/device.dart';

class DeviceModel extends Device {
  const DeviceModel({
    required super.id,
    required super.fcmToken,
    required super.platform,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  });

  factory DeviceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return DeviceModel.fromJson(data, id: doc.id);
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return DeviceModel(
      id: id ?? json['id'] as String? ?? json['deviceId'] as String? ?? '',
      fcmToken: json['fcmToken'] as String? ?? '',
      platform: AppPlatform.fromString(json['platform'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fcmToken': fcmToken,
      'platform': platform.value,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fcmToken': fcmToken,
      'platform': platform.value,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
