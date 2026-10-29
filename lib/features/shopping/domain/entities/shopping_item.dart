import 'package:meta/meta.dart';

@immutable
class ShoppingItem {
  final String id;
  final String shoppingListId;
  final String name;
  final double quantity;
  final String unit;
  final String? note;
  final String? foodId;
  final bool isPurchased;
  final bool isAddedToInventory;
  final String? inventoryItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingItem({
    required this.id,
    required this.shoppingListId,
    required this.name,
    this.quantity = 1.0,
    required this.unit,
    this.note,
    this.foodId,
    this.isPurchased = false,
    this.isAddedToInventory = false,
    this.inventoryItemId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Món đã mua nhưng chưa được nhập vào kho tủ lạnh
  bool get canAddToInventory => isPurchased && !isAddedToInventory;

  /// Món đã nhập kho thì bị khóa tick và khóa sửa
  bool get isLocked => isAddedToInventory;

  ShoppingItem copyWith({
    String? id,
    String? shoppingListId,
    String? name,
    double? quantity,
    String? unit,
    String? note,
    bool clearNote = false,
    String? foodId,
    bool clearFoodId = false,
    bool? isPurchased,
    bool? isAddedToInventory,
    String? inventoryItemId,
    bool clearInventoryItemId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      shoppingListId: shoppingListId ?? this.shoppingListId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      note: clearNote ? null : (note ?? this.note),
      foodId: clearFoodId ? null : (foodId ?? this.foodId),
      isPurchased: isPurchased ?? this.isPurchased,
      isAddedToInventory: isAddedToInventory ?? this.isAddedToInventory,
      inventoryItemId: clearInventoryItemId ? null : (inventoryItemId ?? this.inventoryItemId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingItem && other.id == id && other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, updatedAt);
}
