import 'package:meta/meta.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/string_utils.dart';
import '../entities/shopping_item_draft.dart';
import 'validate_shopping_item_draft.dart';

/// Unit used when the assistant gives an ingredient without one.
const String recipeFallbackUnit = 'phần';

/// An ingredient the AI recipe lists under "to buy". Kept free of the AI
/// feature's types so shopping does not depend on it (PLAN_04 §5).
@immutable
class RecipeShoppingIngredient {
  final String name;
  final double? quantity;
  final String? unit;

  const RecipeShoppingIngredient({
    required this.name,
    this.quantity,
    this.unit,
  });
}

/// Turns the missing ingredients of [recipeTitle] into shopping drafts:
/// fills a missing amount or unit, keeps values inside the shopping limits
/// and merges repeated ingredients with the same name and unit.
class BuildRecipeShoppingDraftsUseCase {
  const BuildRecipeShoppingDraftsUseCase();

  List<ShoppingItemDraft> call({
    required String recipeTitle,
    required List<RecipeShoppingIngredient> ingredients,
  }) {
    final note = _truncate(
      'Cho món ${recipeTitle.trim()}',
      shoppingItemNoteMaxLength,
    );
    final drafts = <String, ShoppingItemDraft>{};
    for (final ingredient in ingredients) {
      final name = _truncate(ingredient.name.trim(), shoppingItemNameMaxLength);
      if (name.isEmpty) continue;
      final rawUnit = ingredient.unit?.trim() ?? '';
      final unit = _truncate(
        rawUnit.isEmpty ? recipeFallbackUnit : rawUnit,
        shoppingItemUnitMaxLength,
      );
      final rawQuantity = ingredient.quantity;
      final quantity =
          rawQuantity == null || !rawQuantity.isFinite || rawQuantity <= 0
          ? 1.0
          : rawQuantity;

      final key = '${StringUtils.normalize(name)}|${unit.toLowerCase()}';
      final existing = drafts[key];
      drafts[key] = ShoppingItemDraft(
        name: existing?.name ?? name,
        quantity: _clamp((existing?.quantity ?? 0) + quantity),
        unit: existing?.unit ?? unit,
        note: note,
        source: ShoppingItemSource.aiRecipe,
      );
    }
    return drafts.values.toList(growable: false);
  }

  static double _clamp(double quantity) =>
      quantity > shoppingItemMaxQuantity ? shoppingItemMaxQuantity : quantity;

  static String _truncate(String text, int maxLength) =>
      text.length > maxLength ? text.substring(0, maxLength).trim() : text;
}
