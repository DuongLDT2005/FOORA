import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/food_category.dart';

/// Data model for a food category (e.g. vegetables, meat, dairy) in Firestore.
class FoodCategoryModel extends FoodCategory {
  const FoodCategoryModel({
    required super.id,
    required super.name,
    required super.code,
    required super.icon,
    super.defaultShelfLife,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Builds a model from a Firestore snapshot.
  factory FoodCategoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FoodCategoryModel.fromJson(data, id: doc.id);
  }

  /// Builds a model from a raw map.
  factory FoodCategoryModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return FoodCategoryModel(
      id: id ?? json['id'] as String? ?? json['categoryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      defaultShelfLife: json['defaultShelfLife'] is Map
          ? Map<String, dynamic>.from(json['defaultShelfLife'] as Map)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  /// Serializes to a Firestore map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'icon': icon,
      'defaultShelfLife': defaultShelfLife,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'icon': icon,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
