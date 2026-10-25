import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class AiRecipe {
  const AiRecipe({
    required this.title,
    required this.usesRefs,
    required this.usedIngredients,
    required this.missingIngredients,
    required this.steps,
    this.cookingMinutes,
  });

  final String title;
  final List<String> usesRefs;
  final List<String> usedIngredients;
  final List<String> missingIngredients;
  final List<String> steps;
  final int? cookingMinutes;

  @override
  bool operator ==(Object other) =>
      other is AiRecipe &&
      other.title == title &&
      const ListEquality<String>().equals(other.usesRefs, usesRefs) &&
      const ListEquality<String>().equals(
        other.usedIngredients,
        usedIngredients,
      ) &&
      const ListEquality<String>().equals(
        other.missingIngredients,
        missingIngredients,
      ) &&
      const ListEquality<String>().equals(other.steps, steps) &&
      other.cookingMinutes == cookingMinutes;

  @override
  int get hashCode => Object.hash(
    title,
    Object.hashAll(usesRefs),
    Object.hashAll(usedIngredients),
    Object.hashAll(missingIngredients),
    Object.hashAll(steps),
    cookingMinutes,
  );
}
