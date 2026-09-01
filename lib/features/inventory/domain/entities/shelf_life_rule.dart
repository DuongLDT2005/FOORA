import 'package:flutter/foundation.dart';

/// Pure domain entity representing a shelf life rule for food storage.
/// Strictly mapped to shelf_life_rules/{ruleId} in docs/DATABASE.md
@immutable
class ShelfLifeRule {
  final String id;
  final String foodId;
  final String storageLocationId;
  final int minDays;
  final int maxDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShelfLifeRule({
    required this.id,
    required this.foodId,
    required this.storageLocationId,
    required this.minDays,
    required this.maxDays,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShelfLifeRule &&
        other.id == id &&
        other.foodId == foodId &&
        other.storageLocationId == storageLocationId &&
        other.minDays == minDays &&
        other.maxDays == maxDays &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    foodId,
    storageLocationId,
    minDays,
    maxDays,
    isActive,
    createdAt,
    updatedAt,
  );
}
