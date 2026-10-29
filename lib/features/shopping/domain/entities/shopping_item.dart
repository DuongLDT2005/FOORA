import 'package:meta/meta.dart';

import '../../../../core/constants/app_enums.dart';

/// One line of a shopping list
/// (`households/{householdId}/shopping_lists/{listId}/items/{itemId}`).
@immutable
class ShoppingItem {
  final String id;
  final String shoppingListId;
  final String name;
  final String normalizedName;
  final double quantity;
  final String unit;
  final String? note;
  final String? foodId;
  final String? categoryId;
  final ShoppingItemSource source;
  final bool isPurchased;
  final String? purchasedBy;
  final bool isAddedToInventory;
  final String? inventoryItemId;
  final String addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingItem({
    required this.id,
    required this.shoppingListId,
    required this.name,
    required this.normalizedName,
    this.quantity = 1.0,
    required this.unit,
    this.note,
    this.foodId,
    this.categoryId,
    this.source = ShoppingItemSource.manual,
    this.isPurchased = false,
    this.purchasedBy,
    this.isAddedToInventory = false,
    this.inventoryItemId,
    this.addedBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Purchased but not yet moved into the fridge.
  bool get canAddToInventory => isPurchased && !isAddedToInventory;

  /// Items already moved into the fridge can no longer be edited or ticked.
  bool get isLocked => isAddedToInventory;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingItem &&
        other.id == id &&
        other.updatedAt == updatedAt &&
        other.isPurchased == isPurchased &&
        other.isAddedToInventory == isAddedToInventory;
  }

  @override
  int get hashCode =>
      Object.hash(id, updatedAt, isPurchased, isAddedToInventory);
}
