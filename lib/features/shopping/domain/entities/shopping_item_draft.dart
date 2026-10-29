import 'package:meta/meta.dart';

import '../../../../core/constants/app_enums.dart';

/// Values entered for a new or edited shopping item, before they are saved.
@immutable
class ShoppingItemDraft {
  final String name;
  final double quantity;
  final String unit;
  final String? note;
  final String? foodId;
  final String? categoryId;
  final ShoppingItemSource source;

  const ShoppingItemDraft({
    required this.name,
    required this.quantity,
    required this.unit,
    this.note,
    this.foodId,
    this.categoryId,
    this.source = ShoppingItemSource.manual,
  });

  ShoppingItemDraft copyWith({
    String? name,
    double? quantity,
    String? unit,
    String? note,
    String? foodId,
    String? categoryId,
    ShoppingItemSource? source,
  }) {
    return ShoppingItemDraft(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      note: note ?? this.note,
      foodId: foodId ?? this.foodId,
      categoryId: categoryId ?? this.categoryId,
      source: source ?? this.source,
    );
  }
}

/// Result of adding an item: [merged] is true when the quantity was added to
/// an existing pending item with the same name and unit.
@immutable
class AddShoppingItemResult {
  final String itemId;
  final bool merged;

  const AddShoppingItemResult({required this.itemId, required this.merged});
}

/// Result of adding several items: how many were new, how many were merged
/// into existing pending items, and the names that could not be saved.
@immutable
class AddShoppingItemsResult {
  final int added;
  final int merged;
  final List<String> failedNames;

  const AddShoppingItemsResult({
    required this.added,
    required this.merged,
    this.failedNames = const [],
  });
}
