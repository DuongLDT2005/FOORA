import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_enums.dart';

import '../../domain/entities/inventory_item.dart';

/// Data model for `households/{householdId}/inventory_items/{id}`.
/// Adds Firestore/JSON conversion on top of the [InventoryItem] entity.
class InventoryItemModel extends InventoryItem {
  const InventoryItemModel({
    required super.id,
    super.foodId,
    required super.name,
    required super.normalizedName,
    required super.categoryId,
    required super.quantity,
    super.initialQuantity,
    required super.unit,
    required super.remainingPercentage,
    required super.storageLocationId,
    required super.purchaseDate,
    required super.expirationDate,
    super.photoUrl,
    super.source = InventoryItemSource.manual,
    super.status = InventoryItemStatus.active,
    super.statusChangedAt,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Builds a model from a Firestore snapshot.
  factory InventoryItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return InventoryItemModel.fromJson(data, id: doc.id);
  }

  /// Builds a model from a raw map; enum fields are parsed from strings.
  factory InventoryItemModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final name = json['name'] as String? ?? '';
    final quantity = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final percentage = (json['remainingPercentage'] as num?)?.toInt() ?? 100;
    final inferredInitial = percentage > 0 && quantity > 0
        ? quantity / (percentage / 100)
        : quantity;
    return InventoryItemModel(
      id:
          id ??
          json['id'] as String? ??
          json['inventoryItemId'] as String? ??
          '',
      foodId: json['foodId'] as String?,
      name: name,
      normalizedName:
          json['normalizedName'] as String? ?? name.toLowerCase().trim(),
      categoryId: json['categoryId'] as String? ?? 'other',
      quantity: quantity,
      initialQuantity:
          (json['initialQuantity'] as num?)?.toDouble() ?? inferredInitial,
      unit: json['unit'] as String? ?? '',
      remainingPercentage:
          (json['remainingPercentage'] as num?)?.toInt() ?? 100,
      storageLocationId: json['storageLocationId'] as String? ?? 'fridge',
      purchaseDate: _parseDateTime(json['purchaseDate']),
      expirationDate: _parseDateTime(json['expirationDate']),
      photoUrl: json['photoUrl'] as String?,
      source: InventoryItemSource.fromString(json['source'] as String?),
      status: InventoryItemStatus.fromString(json['status'] as String?),
      statusChangedAt: _parseDateTimeNullable(json['statusChangedAt']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  /// Wraps a domain [InventoryItem] for serialization.
  factory InventoryItemModel.fromEntity(InventoryItem item) {
    return InventoryItemModel(
      id: item.id,
      foodId: item.foodId,
      name: item.name,
      normalizedName: item.normalizedName,
      categoryId: item.categoryId,
      quantity: item.quantity,
      initialQuantity: item.initialQuantity,
      unit: item.unit,
      remainingPercentage: item.remainingPercentage,
      storageLocationId: item.storageLocationId,
      purchaseDate: item.purchaseDate,
      expirationDate: item.expirationDate,
      photoUrl: item.photoUrl,
      source: item.source,
      status: item.status,
      statusChangedAt: item.statusChangedAt,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  /// Serializes to a Firestore map (dates as [Timestamp]).
  Map<String, dynamic> toFirestore() {
    return {
      'foodId': foodId,
      'name': name,
      'normalizedName': normalizedName,
      'categoryId': categoryId,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'unit': unit,
      'remainingPercentage': remainingPercentage,
      'storageLocationId': storageLocationId,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expirationDate': Timestamp.fromDate(expirationDate),
      'photoUrl': photoUrl,
      'source': source.value,
      'status': status.value,
      'statusChangedAt': statusChangedAt != null
          ? Timestamp.fromDate(statusChangedAt!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Serializes to a JSON map (dates as ISO-8601 strings).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodId': foodId,
      'name': name,
      'normalizedName': normalizedName,
      'categoryId': categoryId,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'unit': unit,
      'remainingPercentage': remainingPercentage,
      'storageLocationId': storageLocationId,
      'purchaseDate': purchaseDate.toIso8601String(),
      'expirationDate': expirationDate.toIso8601String(),
      'photoUrl': photoUrl,
      'source': source.value,
      'status': status.value,
      'statusChangedAt': statusChangedAt?.toIso8601String(),
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

  /// Nullable variant for optional timestamp fields like [statusChangedAt].
  /// Returns null if the field is absent or unrecognised (safe fallback).
  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
