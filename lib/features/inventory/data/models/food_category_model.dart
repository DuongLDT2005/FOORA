import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/food_category.dart';

class FoodCategoryModel extends FoodCategory {
  const FoodCategoryModel({
    required super.id,
    required super.name,
    required super.code,
    required super.icon,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  });

  factory FoodCategoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FoodCategoryModel.fromJson(data, id: doc.id);
  }

  factory FoodCategoryModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return FoodCategoryModel(
      id: id ?? json['id'] as String? ?? json['categoryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'icon': icon,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

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
