import 'package:flutter/foundation.dart';

/// Pure domain entity representing a category of food (e.g. Rau củ, Thịt, Hải sản).
/// Strictly mapped to food_categories/{categoryId} in docs/DATABASE.md
@immutable
class FoodCategory {
  final String id;
  final String name;
  final String code;
  final String icon;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodCategory({
    required this.id,
    required this.name,
    required this.code,
    required this.icon,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodCategory &&
        other.id == id &&
        other.name == name &&
        other.code == code &&
        other.icon == icon &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, code, icon, isActive, createdAt, updatedAt);
}
