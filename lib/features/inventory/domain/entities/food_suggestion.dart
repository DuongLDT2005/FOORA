import 'package:flutter/foundation.dart';

/// Represents a suggestion when a user types in the food name input.
/// Aggregated from Firestore master `foods` and household past inventory items.
@immutable
class FoodSuggestion {
  final String? foodId; // null if from custom household history
  final String name;
  final String categoryId;
  final String defaultUnit;
  final bool isFromMaster; // true if standard food catalog, false if custom past item
  final String? matchedAlias; // Present if matched via alias

  const FoodSuggestion({
    this.foodId,
    required this.name,
    required this.categoryId,
    required this.defaultUnit,
    this.isFromMaster = true,
    this.matchedAlias,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodSuggestion &&
        other.name.toLowerCase() == name.toLowerCase();
  }

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

/// Simple result containing expiration date calculation and rule parameters for UI display.
@immutable
class ExpiryCalculationResult {
  final DateTime expirationDate;
  final num? maxValue;
  final num? minValue;
  final String? unit; // 'days', 'weeks', 'months', 'years'
  final bool hasRule; // true if matched shelf_life_rules or defaultShelfLife

  const ExpiryCalculationResult({
    required this.expirationDate,
    this.maxValue,
    this.minValue,
    this.unit,
    required this.hasRule,
  });
}
