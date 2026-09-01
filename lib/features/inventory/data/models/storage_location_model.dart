import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/storage_location.dart';

class StorageLocationModel extends StorageLocation {
  const StorageLocationModel({
    required super.id,
    required super.name,
    required super.code,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  });

  factory StorageLocationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return StorageLocationModel.fromJson(data, id: doc.id);
  }

  factory StorageLocationModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    return StorageLocationModel(
      id: id ?? json['id'] as String? ?? json['locationId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: StorageLocationCode.fromString(json['code'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code.value,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code.value,
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
