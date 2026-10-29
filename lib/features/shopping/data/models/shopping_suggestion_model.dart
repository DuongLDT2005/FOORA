import '../../domain/entities/shopping_suggestion.dart';

/// Parses one entry of the `getShoppingSuggestions` callable response.
class ShoppingSuggestionModel extends ShoppingSuggestion {
  const ShoppingSuggestionModel({
    required super.key,
    required super.name,
    super.foodId,
    required super.categoryId,
    required super.quantity,
    required super.unit,
    required super.avgIntervalDays,
    required super.daysSinceLastPurchase,
    required super.purchaseCount,
    required super.stockState,
    required super.reason,
  });

  factory ShoppingSuggestionModel.fromJson(Map<String, dynamic> json) {
    return ShoppingSuggestionModel(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      foodId: json['foodId'] as String?,
      categoryId: json['categoryId'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String? ?? '',
      avgIntervalDays: (json['avgIntervalDays'] as num?)?.toDouble() ?? 0,
      daysSinceLastPurchase:
          (json['daysSinceLastPurchase'] as num?)?.toInt() ?? 0,
      purchaseCount: (json['purchaseCount'] as num?)?.toInt() ?? 0,
      stockState: json['stockState'] == 'low'
          ? ShoppingStockState.low
          : ShoppingStockState.out,
      reason: json['reason'] as String? ?? '',
    );
  }
}
