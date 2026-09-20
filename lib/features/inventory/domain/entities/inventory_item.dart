import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_enums.dart';

/// Pure domain entity representing an item stored in a household inventory.
/// Strictly mapped to households/{householdId}/inventory_items/{inventoryItemId} in docs/DATABASE.md
@immutable
class InventoryItem {
  final String id;
  final String?
  foodId; // Nullable when added manually or not mapped to master foods
  final String name;
  final String normalizedName; // Lowercase/unaccented for autocomplete & search
  final String categoryId; // Foreign key to food_categories
  final double quantity;
  final String unit;
  final int remainingPercentage; // 0 to 100
  final String storageLocationId; // Foreign key to storage_locations/{locationId}, e.g. 'fridge', 'freezer'
  final DateTime purchaseDate;
  final DateTime expirationDate;
  final String? photoUrl;
  final InventoryItemSource source;
  final InventoryItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    this.foodId,
    required this.name,
    required this.normalizedName,
    required this.categoryId,
    required this.quantity,
    required this.unit,
    required this.remainingPercentage,
    required this.storageLocationId,
    required this.purchaseDate,
    required this.expirationDate,
    this.photoUrl,
    this.source = InventoryItemSource.manual,
    this.status = InventoryItemStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired => expirationDate.isBefore(DateTime.now());

  InventoryItem copyWith({
    String? id,
    String? foodId,
    String? name,
    String? normalizedName,
    String? categoryId,
    double? quantity,
    String? unit,
    int? remainingPercentage,
    String? storageLocationId,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    String? photoUrl,
    InventoryItemSource? source,
    InventoryItemStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      categoryId: categoryId ?? this.categoryId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      remainingPercentage: remainingPercentage ?? this.remainingPercentage,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expirationDate: expirationDate ?? this.expirationDate,
      photoUrl: photoUrl ?? this.photoUrl,
      source: source ?? this.source,
      status: status ?? this.status,
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
        other.normalizedName == normalizedName &&
        other.categoryId == categoryId &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.remainingPercentage == remainingPercentage &&
        other.storageLocationId == storageLocationId &&
        other.purchaseDate == purchaseDate &&
        other.expirationDate == expirationDate &&
        other.photoUrl == photoUrl &&
        other.source == source &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    foodId,
    name,
    normalizedName,
    categoryId,
    quantity,
    unit,
    remainingPercentage,
    storageLocationId,
    purchaseDate,
    expirationDate,
    photoUrl,
    source,
    status,
    createdAt,
    updatedAt,
  );
}
