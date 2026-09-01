import 'package:flutter/foundation.dart';

/// Pure domain entity representing a line item in a scanned receipt.
/// Strictly mapped to users/{userId}/receipts/{receiptId}/items/{receiptItemId} in docs/DATABASE.md
@immutable
class ReceiptItem {
  final String id;
  final String rawName;
  final String normalizedName;
  final String? foodId;
  final double quantity;
  final String unit;
  final double? confidence;

  const ReceiptItem({
    required this.id,
    required this.rawName,
    required this.normalizedName,
    this.foodId,
    required this.quantity,
    required this.unit,
    this.confidence,
  });

  ReceiptItem copyWith({
    String? id,
    String? rawName,
    String? normalizedName,
    String? foodId,
    double? quantity,
    String? unit,
    double? confidence,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      rawName: rawName ?? this.rawName,
      normalizedName: normalizedName ?? this.normalizedName,
      foodId: foodId ?? this.foodId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptItem &&
        other.id == id &&
        other.rawName == rawName &&
        other.normalizedName == normalizedName &&
        other.foodId == foodId &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.confidence == confidence;
  }

  @override
  int get hashCode => Object.hash(
    id,
    rawName,
    normalizedName,
    foodId,
    quantity,
    unit,
    confidence,
  );
}
