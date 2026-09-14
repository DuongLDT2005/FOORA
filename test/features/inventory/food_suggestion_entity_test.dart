import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/inventory/domain/entities/food_suggestion.dart';

void main() {
  group('FoodSuggestion Entity Tests', () {
    test('equality and hashCode are based on case-insensitive name', () {
      const item1 = FoodSuggestion(
        foodId: 'tomato',
        name: 'Cà chua',
        categoryId: 'vegetables',
        defaultUnit: 'quả',
        isFromMaster: true,
      );

      const item2 = FoodSuggestion(
        foodId: null,
        name: 'cà chua',
        categoryId: 'vegetables',
        defaultUnit: 'kg',
        isFromMaster: false,
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
    });

    test('retains matchedAlias property when matched via alias', () {
      const suggestion = FoodSuggestion(
        foodId: 'pork-belly',
        name: 'Thịt ba chỉ heo',
        categoryId: 'meat',
        defaultUnit: 'kg',
        isFromMaster: true,
        matchedAlias: 'thịt lợn',
      );

      expect(suggestion.matchedAlias, 'thịt lợn');
      expect(suggestion.isFromMaster, isTrue);
    });
  });

  group('ExpiryCalculationResult Entity Tests', () {
    test('instantiates calculation result with rule metadata', () {
      final expiry = DateTime(2026, 9, 20);
      final result = ExpiryCalculationResult(
        expirationDate: expiry,
        maxValue: 5,
        minValue: 3,
        unit: 'days',
        hasRule: true,
      );

      expect(result.expirationDate, expiry);
      expect(result.maxValue, 5);
      expect(result.minValue, 3);
      expect(result.unit, 'days');
      expect(result.hasRule, isTrue);
    });
  });
}
