import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/string_utils.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_item_draft.dart';

class ShoppingItemModel extends ShoppingItem {
  const ShoppingItemModel({
    required super.id,
    required super.shoppingListId,
    required super.name,
    required super.normalizedName,
    super.quantity,
    required super.unit,
    super.note,
    super.foodId,
    super.categoryId,
    super.source,
    super.isPurchased,
    super.purchasedBy,
    super.isAddedToInventory,
    super.inventoryItemId,
    super.addedBy,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ShoppingItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String shoppingListId,
  }) {
    return ShoppingItemModel.fromJson(
      doc.data() ?? const {},
      id: doc.id,
      shoppingListId: shoppingListId,
    );
  }

  factory ShoppingItemModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
    required String shoppingListId,
  }) {
    final name = json['name'] as String? ?? '';
    return ShoppingItemModel(
      id: id,
      shoppingListId: shoppingListId,
      name: name,
      normalizedName:
          json['normalizedName'] as String? ?? StringUtils.normalize(name),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? '',
      note: json['note'] as String?,
      foodId: json['foodId'] as String?,
      categoryId: json['categoryId'] as String?,
      source: ShoppingItemSource.fromString(json['source'] as String?),
      isPurchased: json['isPurchased'] as bool? ?? false,
      purchasedBy: json['purchasedBy'] as String?,
      isAddedToInventory: json['isAddedToInventory'] as bool? ?? false,
      inventoryItemId: json['inventoryItemId'] as String?,
      addedBy: json['addedBy'] as String? ?? '',
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Fields of a brand-new item. Must match the `create` rule exactly.
  static Map<String, dynamic> newItemData({
    required ShoppingItemDraft draft,
    required String normalizedName,
    required String addedBy,
  }) {
    final now = FieldValue.serverTimestamp();
    return {
      ...editableData(draft: draft, normalizedName: normalizedName),
      'source': draft.source.value,
      'isPurchased': false,
      'purchasedBy': null,
      'purchasedAt': null,
      'isAddedToInventory': false,
      'inventoryItemId': null,
      'addedToInventoryAt': null,
      'addedBy': addedBy,
      'createdAt': now,
      'updatedAt': now,
    };
  }

  /// Fields a member may change on a pending item.
  static Map<String, dynamic> editableData({
    required ShoppingItemDraft draft,
    required String normalizedName,
  }) {
    return {
      'name': draft.name,
      'normalizedName': normalizedName,
      'quantity': draft.quantity,
      'unit': draft.unit,
      'note': draft.note,
      'foodId': draft.foodId,
      'categoryId': draft.categoryId,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
