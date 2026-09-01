import 'package:flutter/foundation.dart';
import 'package:foora/core/constants/app_enums.dart';

/// Pure domain entity representing an item stored in a household inventory.
/// Strictly mapped to households/{householdId}/inventory_items/{inventoryItemId} in docs/DATABASE.md
@immutable
class InventoryItem {
  final String id;
  final String foodId;
  final String name;
  final double quantity;
  final String unit;
  final int remainingPercentage; // 0 to 100
  final String storageLocationId; // Foreign key to storage_locations/{locationId}, e.g. 'fridge', 'freezer'
  final DateTime purchaseDate;
  final DateTime expirationDate;
  final InventoryItemSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.foodId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.remainingPercentage,
    required this.storageLocationId,
    required this.purchaseDate,
    required this.expirationDate,
    this.source = InventoryItemSource.manual,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired => expirationDate.isBefore(DateTime.now());

  InventoryItem copyWith({
    String? id,
    String? foodId,
    String? name,
    double? quantity,
    String? unit,
    int? remainingPercentage,
    String? storageLocationId,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    InventoryItemSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      remainingPercentage: remainingPercentage ?? this.remainingPercentage,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expirationDate: expirationDate ?? this.expirationDate,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryItem &&
        other.id == id &&
        other.foodId == foodId &&
        other.name == name &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.remainingPercentage == remainingPercentage &&
        other.storageLocationId == storageLocationId &&
        other.purchaseDate == purchaseDate &&
        other.expirationDate == expirationDate &&
        other.source == source &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    foodId,
    name,
    quantity,
    unit,
    remainingPercentage,
    storageLocationId,
    purchaseDate,
    expirationDate,
    source,
    createdAt,
    updatedAt,
  );
}
