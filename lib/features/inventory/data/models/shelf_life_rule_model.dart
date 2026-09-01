import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/shelf_life_rule.dart';

class ShelfLifeRuleModel extends ShelfLifeRule {
  const ShelfLifeRuleModel({
    required super.id,
    required super.foodId,
    required super.storageLocationId,
    required super.minDays,
    required super.maxDays,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ShelfLifeRuleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ShelfLifeRuleModel.fromJson(data, id: doc.id);
  }

  factory ShelfLifeRuleModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ShelfLifeRuleModel(
      id: id ?? json['id'] as String? ?? json['ruleId'] as String? ?? '',
      foodId: json['foodId'] as String? ?? '',
      storageLocationId: json['storageLocationId'] as String? ?? '',
      minDays: (json['minDays'] as num?)?.toInt() ?? 0,
      maxDays: (json['maxDays'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'foodId': foodId,
      'storageLocationId': storageLocationId,
      'minDays': minDays,
      'maxDays': maxDays,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodId': foodId,
      'storageLocationId': storageLocationId,
      'minDays': minDays,
      'maxDays': maxDays,
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
