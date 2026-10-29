import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/ai/domain/services/ai_food_category.dart';

void main() {
  test('suggests clear food categories for old AI proposals', () {
    expect(suggestAiCategoryId('gà'), 'meat');
    expect(suggestAiCategoryId('thịt bò'), 'meat');
    expect(suggestAiCategoryId('cua'), 'seafood');
    expect(suggestAiCategoryId('rau muống'), 'vegetables');
    expect(suggestAiCategoryId('cà chua'), 'vegetables');
    expect(suggestAiCategoryId('nấm đùi gà'), 'vegetables');
    expect(suggestAiCategoryId('món lạ'), isNull);
  });
}
