import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/ai/domain/entities/ai_action.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_message.dart';
import 'package:foora/features/ai/domain/entities/ai_recipe.dart';
import 'package:foora/features/ai/domain/usecases/watch_ai_quota.dart';
import 'package:foora/features/ai/presentation/widgets/ai_chat_suggestions.dart';
import 'package:foora/features/inventory/domain/entities/inventory_item.dart';

final _now = DateTime(2026, 10, 27, 20);

InventoryItem _item(
  String name,
  DateTime expiry, {
  double quantity = 1,
  String unit = 'quả',
  InventoryItemStatus status = InventoryItemStatus.active,
}) => InventoryItem(
  id: name,
  name: name,
  normalizedName: name.toLowerCase(),
  categoryId: 'x',
  quantity: quantity,
  unit: unit,
  remainingPercentage: 100,
  storageLocationId: 'fridge',
  purchaseDate: DateTime(2026, 10, 20),
  expirationDate: expiry,
  status: status,
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 20),
);

AiChatMessage _answer({
  String content = 'Được.',
  List<AiRecipe> recipes = const [],
  List<AiAction> actions = const [],
}) => AiChatMessage(
  id: 'a',
  content: content,
  isUser: false,
  timestamp: _now,
  recipes: recipes,
  actions: actions,
);

void main() {
  test('follow-ups match the answer and skip receipts', () {
    const dish = AiRecipe(
      title: 'Trứng chiên',
      servings: 2,
      ingredients: [AiRecipeIngredient(name: 'Trứng')],
    );
    expect(aiFollowUps(_answer(recipes: [dish])), [
      'Gợi ý món khác',
      'Món nào nấu nhanh hơn?',
      'Điều chỉnh cho 4 người',
    ]);
    expect(
      aiFollowUps(_answer(content: 'Thịt bò sắp hết hạn.')).first,
      'Nấu gì với những món này?',
    );
    expect(
      aiFollowUps(
        _answer(
          actions: const [
            AiAction(
              actionId: '1',
              type: 'consume',
              name: 'Trứng',
              candidateBatches: [],
              reviewState: 'ready',
              resolution: 'pending',
            ),
          ],
        ),
      ),
      isEmpty,
    );
  });

  test('welcome suggestions name the soonest usable foods', () {
    final suggestions = aiWelcomeSuggestions([
      _item('Sữa', DateTime(2026, 10, 26)),
      _item('Cà chua', DateTime(2026, 10, 30)),
      _item('Thịt bò', DateTime(2026, 10, 28), quantity: 500, unit: 'g'),
      _item('Trứng', DateTime(2026, 10, 27), quantity: 0),
      _item(
        'Tôm',
        DateTime(2026, 10, 27),
        status: InventoryItemStatus.consumed,
      ),
    ], _now);
    expect(suggestions, [
      'Trong tủ còn thực phẩm nào sắp hết hạn?',
      'Nấu gì với Thịt bò và Cà chua?',
      'Thịt bò hết hạn ngày mai, nên dùng thế nào?',
      'Tôi đã dùng 100 g Thịt bò',
    ]);
    expect(aiWelcomeSuggestions(const [], _now), hasLength(3));
  });

  test('expiry labels count calendar days', () {
    expect(aiExpiryLabel(DateTime(2026, 10, 27), _now), 'hết hạn hôm nay');
    expect(aiExpiryLabel(DateTime(2026, 10, 28), _now), 'hết hạn ngày mai');
    expect(aiExpiryLabel(DateTime(2026, 11, 1), _now), 'còn 5 ngày');
    expect(aiExpiryLabel(DateTime(2026, 10, 25), _now), 'đã quá hạn');
  });

  test('quota day follows Vietnam time like the backend', () {
    expect(aiQuotaDay(DateTime.utc(2026, 10, 22, 16, 59)), '2026-10-22');
    expect(aiQuotaDay(DateTime.utc(2026, 10, 22, 17)), '2026-10-23');
  });
}
