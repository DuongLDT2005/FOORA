import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class AiRecipeIngredient {
  const AiRecipeIngredient({
    required this.name,
    this.quantity,
    this.unit,
    this.itemId,
    this.expirationDate,
  });

  final String name;
  final double? quantity;
  final String? unit;

  /// Inventory item the ingredient comes from; null when it must be bought.
  final String? itemId;

  /// Day the linked fridge item expires (date only); null when bought.
  final DateTime? expirationDate;

  bool get inInventory => itemId != null;

  @override
  bool operator ==(Object other) =>
      other is AiRecipeIngredient &&
      other.name == name &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.itemId == itemId &&
      other.expirationDate == expirationDate;

  @override
  int get hashCode => Object.hash(name, quantity, unit, itemId, expirationDate);
}

/// A suggested dish: ingredients and amounts only. Suggestions never change
/// inventory; the user reports what they cooked in a later message.
@immutable
class AiRecipe {
  const AiRecipe({
    required this.title,
    required this.ingredients,
    this.servings,
  });

  final String title;
  final List<AiRecipeIngredient> ingredients;
  final int? servings;

  List<String> get usesRefs => [
    for (final ingredient in ingredients)
      if (ingredient.itemId != null) ingredient.itemId!,
  ];

  List<String> get missingIngredients => [
    for (final ingredient in ingredients)
      if (!ingredient.inInventory) ingredient.name,
  ];

  @override
  bool operator ==(Object other) =>
      other is AiRecipe &&
      other.title == title &&
      other.servings == servings &&
      const ListEquality<AiRecipeIngredient>().equals(
        other.ingredients,
        ingredients,
      );

  @override
  int get hashCode => Object.hash(title, servings, Object.hashAll(ingredients));
}
