import 'package:flutter/foundation.dart';

/// Stock duplicate matching info inside active household inventory (Smart Query / FEFO Alert)
@immutable
class MatchedStockAlert {
  final String itemId;
  final String name;
  final double quantity;
  final String unit;
  final String storageLocationName;
  final DateTime expirationDate;
  final int daysRemaining;

  const MatchedStockAlert({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.storageLocationName,
    required this.expirationDate,
    required this.daysRemaining,
  });

  bool get isExpiringToday => daysRemaining <= 0;
}

/// Pure domain entity representing a line item in a scanned receipt.
/// Strictly mapped to users/{userId}/receipts/{receiptId}/items/{receiptItemId} in docs/DATABASE.md
@immutable
class ReceiptItem {
  final String id;
  final String rawName;
  final String name;
  final String normalizedName;
  final String? foodId;
  final String categoryId;
  final double quantity;
  final String unit;
  final String storageLocationId;
  final DateTime estimatedExpirationDate;
  final double? confidence;
  final String? photoUrl;
  final MatchedStockAlert? matchedExistingItem;

  const ReceiptItem({
    required this.id,
    required this.rawName,
    required this.name,
    required this.normalizedName,
    this.foodId,
    this.categoryId = 'vegetables',
    required this.quantity,
    required this.unit,
    this.storageLocationId = 'fridge',
    required this.estimatedExpirationDate,
    this.confidence,
    this.photoUrl,
    this.matchedExistingItem,
  });

  ReceiptItem copyWith({
    String? id,
    String? rawName,
    String? name,
    String? normalizedName,
    String? foodId,
    String? categoryId,
    double? quantity,
    String? unit,
    String? storageLocationId,
    DateTime? estimatedExpirationDate,
    double? confidence,
    String? photoUrl,
    MatchedStockAlert? matchedExistingItem,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      rawName: rawName ?? this.rawName,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      foodId: foodId ?? this.foodId,
      categoryId: categoryId ?? this.categoryId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      estimatedExpirationDate:
          estimatedExpirationDate ?? this.estimatedExpirationDate,
      confidence: confidence ?? this.confidence,
      photoUrl: photoUrl ?? this.photoUrl,
      matchedExistingItem: matchedExistingItem ?? this.matchedExistingItem,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptItem &&
        other.id == id &&
        other.rawName == rawName &&
        other.name == name &&
        other.normalizedName == normalizedName &&
        other.foodId == foodId &&
        other.categoryId == categoryId &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.storageLocationId == storageLocationId &&
        other.estimatedExpirationDate == estimatedExpirationDate &&
        other.confidence == confidence &&
        other.photoUrl == photoUrl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    rawName,
    name,
    normalizedName,
    foodId,
    categoryId,
    quantity,
    unit,
    storageLocationId,
    estimatedExpirationDate,
    confidence,
    photoUrl,
  );
}
