import 'package:meta/meta.dart';

/// Stock level that made the backend suggest an item.
enum ShoppingStockState { out, low }

/// "Frequently bought" suggestion computed by `getShoppingSuggestions`.
@immutable
class ShoppingSuggestion {
  final String key;
  final String name;
  final String? foodId;
  final String categoryId;
  final double quantity;
  final String unit;
  final double avgIntervalDays;
  final int daysSinceLastPurchase;
  final int purchaseCount;
  final ShoppingStockState stockState;

  /// Ready-to-show Vietnamese explanation.
  final String reason;

  const ShoppingSuggestion({
    required this.key,
    required this.name,
    this.foodId,
    required this.categoryId,
    required this.quantity,
    required this.unit,
    required this.avgIntervalDays,
    required this.daysSinceLastPurchase,
    required this.purchaseCount,
    required this.stockState,
    required this.reason,
  });
}
