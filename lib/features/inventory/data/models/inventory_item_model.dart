import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_enums.dart';

import '../../domain/entities/inventory_item.dart';

class InventoryItemModel extends InventoryItem {
  const InventoryItemModel({
    required super.id,
    super.foodId,
    required super.name,
    required super.normalizedName,
    required super.categoryId,
    required super.quantity,
    required super.unit,
    required super.remainingPercentage,
    required super.storageLocationId,
    required super.purchaseDate,
    required super.expirationDate,
    super.source = InventoryItemSource.manual,
    super.status = InventoryItemStatus.active,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InventoryItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return InventoryItemModel.fromJson(data, id: doc.id);
  }

  factory InventoryItemModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final name = json['name'] as String? ?? '';
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
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      remainingPercentage:
          (json['remainingPercentage'] as num?)?.toInt() ?? 100,
      storageLocationId: json['storageLocationId'] as String? ?? 'fridge',
      purchaseDate: _parseDateTime(json['purchaseDate']),
      expirationDate: _parseDateTime(json['expirationDate']),
      source: InventoryItemSource.fromString(json['source'] as String?),
      status: InventoryItemStatus.fromString(json['status'] as String?),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  factory InventoryItemModel.fromEntity(InventoryItem item) {
    return InventoryItemModel(
      id: item.id,
      foodId: item.foodId,
      name: item.name,
      normalizedName: item.normalizedName,
      categoryId: item.categoryId,
      quantity: item.quantity,
      unit: item.unit,
      remainingPercentage: item.remainingPercentage,
      storageLocationId: item.storageLocationId,
      purchaseDate: item.purchaseDate,
      expirationDate: item.expirationDate,
      source: item.source,
      status: item.status,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'foodId': foodId,
      'name': name,
      'normalizedName': normalizedName,
      'categoryId': categoryId,
      'quantity': quantity,
      'unit': unit,
      'remainingPercentage': remainingPercentage,
      'storageLocationId': storageLocationId,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expirationDate': Timestamp.fromDate(expirationDate),
      'source': source.value,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodId': foodId,
      'name': name,
      'normalizedName': normalizedName,
      'categoryId': categoryId,
      'quantity': quantity,
      'unit': unit,
      'remainingPercentage': remainingPercentage,
      'storageLocationId': storageLocationId,
      'purchaseDate': purchaseDate.toIso8601String(),
      'expirationDate': expirationDate.toIso8601String(),
      'source': source.value,
      'status': status.value,
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
