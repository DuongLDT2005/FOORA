import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/shopping_item.dart';

class ShoppingItemModel extends ShoppingItem {
  const ShoppingItemModel({
    required super.id,
    required super.shoppingListId,
    required super.name,
    super.quantity = 1.0,
    required super.unit,
    super.note,
    super.foodId,
    super.isPurchased = false,
    super.isAddedToInventory = false,
    super.inventoryItemId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ShoppingItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? shoppingListId,
  }) {
    final data = doc.data() ?? {};
    return ShoppingItemModel.fromJson(
      data,
      id: doc.id,
      shoppingListId: shoppingListId,
    );
  }

  factory ShoppingItemModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
    String? shoppingListId,
  }) {
    return ShoppingItemModel(
      id: id ?? json['id'] as String? ?? '',
      shoppingListId: shoppingListId ?? json['shoppingListId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? '',
      note: json['note'] as String?,
      foodId: json['foodId'] as String?,
      isPurchased: json['isPurchased'] as bool? ?? false,
      isAddedToInventory: json['isAddedToInventory'] as bool? ?? false,
      inventoryItemId: json['inventoryItemId'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'quantity': quantity,
      'unit': unit.trim(),
      'note': (note != null && note!.trim().isNotEmpty) ? note!.trim() : null,
      'foodId': foodId,
      'isPurchased': isPurchased,
      'isAddedToInventory': isAddedToInventory,
      'inventoryItemId': inventoryItemId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ShoppingItem toEntity() => this;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
