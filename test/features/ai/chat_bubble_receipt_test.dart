import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/ai/domain/entities/ai_action.dart';
import 'package:foora/features/ai/domain/entities/ai_assistant_response.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_message.dart';
import 'package:foora/features/ai/domain/entities/ai_recipe.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_session.dart';
import 'package:foora/features/ai/domain/repositories/ai_repository.dart';
import 'package:foora/features/ai/domain/usecases/apply_ai_actions.dart';
import 'package:foora/features/ai/presentation/providers/ai_provider.dart';
import 'package:foora/features/ai/presentation/widgets/ai_consume_receipt_card.dart';
import 'package:foora/features/ai/presentation/widgets/chat_bubble.dart';
import 'package:foora/features/inventory/domain/entities/food_category.dart';
import 'package:foora/features/inventory/domain/entities/storage_location.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';

class _FakeAiRepository implements AiRepository {
  @override
  Stream<AiAssistantQuota> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  }) => const Stream.empty();

  String? appliedMessageId;
  List<Map<String, dynamic>>? appliedDecisions;

  @override
  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  }) async {
    appliedMessageId = messageId;
    appliedDecisions = decisions;
    return {};
  }

  @override
  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  }) => throw UnimplementedError();

  @override
  Stream<List<AiChatMessage>> watchMessages({
    required String userId,
    required String sessionId,
  }) => const Stream.empty();

  @override
  Stream<List<AiChatSession>> watchSessions({
    required String userId,
    required String householdId,
  }) => const Stream.empty();
}

void main() {
  testWidgets('shows an inventory entry receipt awaiting confirmation', (
    tester,
  ) async {
    var opened = false;
    final message = AiChatMessage(
      id: 'assistant',
      content: 'Hãy kiểm tra phiếu nhập.',
      isUser: false,
      timestamp: DateTime(2026),
      actionStatus: 'proposed',
      actions: const [
        AiAction(
          actionId: 'fish',
          type: 'add_inventory',
          name: 'Cá',
          quantity: 10,
          unit: 'kg',
          candidateBatches: [],
          reviewState: 'needsReview',
          resolution: 'pending',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodCategoriesProvider.overrideWith((ref) async => []),
          storageLocationsProvider.overrideWith((ref) async => []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: message,
                onReviewActions: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Phiếu nhập tủ lạnh'), findsOneWidget);
    expect(find.text('Cá'), findsOneWidget);
    expect(find.text('10 kg'), findsOneWidget);
    expect(find.text('Chưa nhập kho · Kiểm tra rồi xác nhận'), findsOneWidget);
    expect(find.text('Xác nhận nhập kho'), findsOneWidget);
    await tester.tap(find.text('Sửa tên, lượng hoặc hạn dùng'));
    expect(opened, isTrue);
  });

  testWidgets('confirms all receipt lines inline', (tester) async {
    final repository = _FakeAiRepository();
    final now = DateTime(2026);
    final message = AiChatMessage(
      id: 'saved-assistant',
      content: 'Phiếu nhập 1 món.',
      isUser: false,
      timestamp: now,
      actionStatus: 'proposed',
      actions: const [
        AiAction(
          actionId: 'pork',
          type: 'add_inventory',
          name: 'Thịt heo',
          quantity: 1,
          unit: 'kg',
          storageLocationId: 'fridge',
          candidateBatches: [],
          reviewState: 'needsReview',
          resolution: 'pending',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applyAiActionsProvider.overrideWith(
            (ref) => ApplyAiActions(repository),
          ),
          foodCategoriesProvider.overrideWith(
            (ref) async => [
              FoodCategory(
                id: 'meat',
                name: 'Thịt',
                code: 'MEAT',
                icon: 'beef',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
          storageLocationsProvider.overrideWith(
            (ref) async => [
              StorageLocation(
                id: 'fridge',
                name: 'Ngăn mát',
                code: StorageLocationCode.fridge,
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => MaterialApp(
            home: Scaffold(body: ChatBubble(message: message)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Thịt'), findsOneWidget);
    await tester.tap(find.text('Xác nhận nhập kho'));
    await tester.pump();
    expect(repository.appliedMessageId, 'saved-assistant');
    expect(repository.appliedDecisions, [
      {
        'actionId': 'pork',
        'accept': true,
        'name': 'Thịt heo',
        'quantity': 1.0,
        'unit': 'kg',
        'categoryId': 'meat',
        'storageLocationId': 'fridge',
      },
    ]);
  });

  testWidgets('consume receipt confirms only the decision for FEFO', (
    tester,
  ) async {
    final repository = _FakeAiRepository();
    await tester.pumpWidget(
      _bubble(
        repository,
        _consumeMessage(
          const AiAction(
            actionId: 'eggs',
            type: 'consume',
            name: 'Trứng gà',
            quantity: 5,
            unit: 'quả',
            candidateBatches: [
              AiActionCandidate(
                itemId: 'a',
                name: 'Trứng gà',
                quantity: 2,
                unit: 'quả',
                expirationDate: '2026-10-27',
              ),
              AiActionCandidate(
                itemId: 'b',
                name: 'Trứng gà',
                quantity: 10,
                unit: 'quả',
                expirationDate: '2026-11-05',
              ),
            ],
            reviewState: 'ready',
            resolution: 'pending',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Trừ dần từ 2 lô, lô gần hết hạn trước'), findsOneWidget);
    await tester.tap(find.text('Xác nhận cập nhật kho'));
    await tester.pump();
    expect(repository.appliedDecisions, [
      {'actionId': 'eggs', 'accept': true},
    ]);
  });

  testWidgets('consume receipt that needs review opens the sheet instead', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      _bubble(
        _FakeAiRepository(),
        _consumeMessage(
          const AiAction(
            actionId: 'eggs',
            type: 'consume',
            name: 'Trứng gà',
            unit: 'quả',
            candidateBatches: [],
            reviewState: 'needsReview',
            resolution: 'pending',
          ),
        ),
        onReview: () => opened = true,
      ),
    );
    await tester.pump();
    expect(find.text('Chưa rõ lượng'), findsOneWidget);
    expect(find.text('Xác nhận cập nhật kho'), findsNothing);
    await tester.tap(find.text('Kiểm tra và chọn lô'));
    expect(opened, isTrue);
  });

  testWidgets('entry receipt buttons span the card width', (tester) async {
    await tester.pumpWidget(
      _bubble(
        _FakeAiRepository(),
        AiChatMessage(
          id: 'entry',
          content: 'Phiếu nhập 1 món.',
          isUser: false,
          timestamp: DateTime(2026),
          actionStatus: 'proposed',
          actions: const [
            AiAction(
              actionId: 'pork',
              type: 'add_inventory',
              name: 'Thịt heo',
              quantity: 1,
              unit: 'kg',
              categoryId: 'meat',
              storageLocationId: 'fridge',
              candidateBatches: [],
              reviewState: 'needsReview',
              resolution: 'pending',
            ),
          ],
        ),
        onReview: () {},
      ),
    );
    await tester.pump();
    final confirm = tester.getRect(find.byType(FilledButton));
    final edit = tester.getRect(find.byType(TextButton));
    expect(edit.left, confirm.left);
    expect(edit.width, confirm.width);
  });

  testWidgets('consume receipt that needs review has a full-width button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bubble(
        _FakeAiRepository(),
        _consumeMessage(
          const AiAction(
            actionId: 'eggs',
            type: 'consume',
            name: 'Trứng gà',
            unit: 'quả',
            candidateBatches: [],
            reviewState: 'needsReview',
            resolution: 'pending',
          ),
        ),
        onReview: () {},
      ),
    );
    await tester.pump();
    final card = tester.getRect(find.byType(AiConsumeReceiptCard));
    final review = tester.getRect(find.byType(FilledButton));
    // Only the card's 16px side padding is left on each side.
    expect(review.width, closeTo(card.width - 2 * 16.w, 2));
  });

  testWidgets('a catalog-matched entry line keeps its foodId', (tester) async {
    final repository = _FakeAiRepository();
    final now = DateTime(2026);
    await tester.pumpWidget(
      _bubble(
        repository,
        AiChatMessage(
          id: 'saved-assistant',
          content: 'Phiếu nhập 1 món.',
          isUser: false,
          timestamp: now,
          actionStatus: 'proposed',
          actions: const [
            AiAction(
              actionId: 'pork',
              type: 'add_inventory',
              name: 'Thịt ba chỉ',
              spokenName: 'ba rọi heo',
              foodId: 'pork-belly',
              expirationDate: '2026-10-29',
              quantity: 1,
              unit: 'kg',
              categoryId: 'meat',
              storageLocationId: 'fridge',
              candidateBatches: [],
              reviewState: 'needsReview',
              resolution: 'pending',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('Bạn nói: ba rọi heo · HSD dự kiến 29/10/2026'),
      findsOneWidget,
    );
    await tester.tap(find.text('Xác nhận nhập kho'));
    await tester.pump();
    expect(repository.appliedDecisions!.single['foodId'], 'pork-belly');
  });

  testWidgets('a recipe marks the part of a fridge item still to buy', (
    tester,
  ) async {
    final message = AiChatMessage(
      id: 'dish-assistant',
      content: 'Món cho 4 người.',
      isUser: false,
      timestamp: DateTime(2026),
      recipes: const [
        AiRecipe(
          title: 'Bò xào',
          servings: 4,
          ingredients: [
            AiRecipeIngredient(
              name: 'Thịt bò',
              quantity: 500,
              unit: 'g',
              itemId: 'beef',
            ),
            AiRecipeIngredient(name: 'Thịt bò', quantity: 500, unit: 'g'),
            AiRecipeIngredient(name: 'Hành tây', quantity: 1, unit: 'củ'),
          ],
        ),
      ],
    );
    await tester.pumpWidget(_bubble(_FakeAiRepository(), message));
    await tester.pump();

    expect(find.text('Thịt bò'), findsNWidgets(2));
    expect(find.text('Tủ không đủ, cần mua thêm'), findsOneWidget);
  });

  testWidgets('a recipe with items to buy offers the shopping list', (
    tester,
  ) async {
    AiRecipe? tapped;
    const recipe = AiRecipe(
      title: 'Canh chua',
      ingredients: [
        AiRecipeIngredient(name: 'Cá lóc', quantity: 1, unit: 'con'),
      ],
    );
    final message = AiChatMessage(
      id: 'shop-assistant',
      content: 'Gợi ý món.',
      isUser: false,
      timestamp: DateTime(2026),
      recipes: const [recipe],
    );
    await tester.pumpWidget(
      _bubble(
        _FakeAiRepository(),
        message,
        onAddToShopping: (value) => tapped = value,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Thêm vào danh sách mua'));
    expect(tapped, recipe);
  });

  testWidgets('a recipe fully in the fridge hides the shopping button', (
    tester,
  ) async {
    final message = AiChatMessage(
      id: 'stocked-assistant',
      content: 'Gợi ý món.',
      isUser: false,
      timestamp: DateTime(2026),
      recipes: const [
        AiRecipe(
          title: 'Trứng chiên',
          ingredients: [
            AiRecipeIngredient(name: 'Trứng', quantity: 2, itemId: 'egg'),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      _bubble(_FakeAiRepository(), message, onAddToShopping: (_) {}),
    );
    await tester.pump();

    expect(find.text('Thêm vào danh sách mua'), findsNothing);
  });
}

AiChatMessage _consumeMessage(AiAction action) => AiChatMessage(
  id: 'consume-assistant',
  content: 'Tôi đã lập phiếu trừ.',
  isUser: false,
  timestamp: DateTime(2026),
  actionStatus: 'proposed',
  actions: [action],
);

Widget _bubble(
  _FakeAiRepository repository,
  AiChatMessage message, {
  VoidCallback? onReview,
  ValueChanged<AiRecipe>? onAddToShopping,
}) {
  final now = DateTime(2026);
  return ProviderScope(
    overrides: [
      applyAiActionsProvider.overrideWith((ref) => ApplyAiActions(repository)),
      foodCategoriesProvider.overrideWith(
        (ref) async => [
          FoodCategory(
            id: 'meat',
            name: 'Thịt',
            code: 'MEAT',
            icon: 'beef',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      storageLocationsProvider.overrideWith(
        (ref) async => [
          StorageLocation(
            id: 'fridge',
            name: 'Ngăn mát',
            code: StorageLocationCode.fridge,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatBubble(
              message: message,
              onReviewActions: onReview,
              onAddToShopping: onAddToShopping,
            ),
          ),
        ),
      ),
    ),
  );
}
