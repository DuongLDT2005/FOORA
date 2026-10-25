import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/ai/domain/entities/ai_action.dart';
import 'package:foora/features/ai/domain/entities/ai_assistant_response.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_message.dart';
import 'package:foora/features/ai/domain/repositories/ai_repository.dart';
import 'package:foora/features/ai/domain/usecases/apply_ai_actions.dart';
import 'package:foora/features/ai/presentation/providers/ai_provider.dart';
import 'package:foora/features/ai/presentation/widgets/chat_bubble.dart';
import 'package:foora/features/inventory/domain/entities/food_category.dart';
import 'package:foora/features/inventory/domain/entities/storage_location.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';

class _FakeAiRepository implements AiRepository {
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
    required String requestId,
    required String message,
    required String inputMode,
  }) => throw UnimplementedError();

  @override
  Stream<List<AiChatMessage>> watchMessages({
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
}
