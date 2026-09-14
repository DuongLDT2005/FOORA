import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/inventory/domain/entities/food_suggestion.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_form_state.dart';

void main() {
  group('InventoryFormState Tests', () {
    test('initial state sets appropriate defaults without editing item', () {
      final state = InventoryFormState.initial();

      expect(state.name, '');
      expect(state.quantity, 1.0);
      expect(state.unit, 'quả');
      expect(state.remainingPercentage, 100);
      expect(state.showSuggestions, isFalse);
      expect(state.suggestions, isEmpty);
      expect(state.hasShelfLifeRule, isFalse);
      expect(state.maxStorageTime, isNull);
    });

    test('copyWith updates suggestions and shelf life rule metadata', () {
      final initialState = InventoryFormState.initial();

      const suggestions = [
        FoodSuggestion(
          foodId: 'beef-steak',
          name: 'Thịt bò bít tết',
          categoryId: 'meat',
          defaultUnit: 'kg',
          isFromMaster: true,
        ),
      ];

      final updatedState = initialState.copyWith(
        name: 'Thịt bò',
        suggestions: suggestions,
        showSuggestions: true,
        maxStorageTime: 5,
        minStorageTime: 3,
        storageTimeUnit: 'days',
        hasShelfLifeRule: true,
      );

      expect(updatedState.name, 'Thịt bò');
      expect(updatedState.suggestions.length, 1);
      expect(updatedState.showSuggestions, isTrue);
      expect(updatedState.maxStorageTime, 5);
      expect(updatedState.minStorageTime, 3);
      expect(updatedState.storageTimeUnit, 'days');
      expect(updatedState.hasShelfLifeRule, isTrue);
    });

    test('clearShelfLifeRule clears rule parameters cleanly', () {
      final stateWithRule = InventoryFormState.initial().copyWith(
        maxStorageTime: 12,
        storageTimeUnit: 'months',
        hasShelfLifeRule: true,
      );

      expect(stateWithRule.hasShelfLifeRule, isTrue);

      final clearedState = stateWithRule.copyWith(clearShelfLifeRule: true);
      expect(clearedState.hasShelfLifeRule, isFalse);
      expect(clearedState.maxStorageTime, isNull);
      expect(clearedState.storageTimeUnit, isNull);
    });
  });
}
