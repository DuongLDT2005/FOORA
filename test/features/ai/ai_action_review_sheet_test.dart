import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/ai/domain/entities/ai_action.dart';
import 'package:foora/features/ai/domain/entities/ai_assistant_response.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_message.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_session.dart';
import 'package:foora/features/ai/domain/repositories/ai_repository.dart';
import 'package:foora/features/ai/domain/usecases/apply_ai_actions.dart';
import 'package:foora/features/ai/presentation/providers/ai_provider.dart';
import 'package:foora/features/ai/presentation/widgets/ai_action_review_sheet.dart';
import 'package:foora/features/inventory/domain/entities/food_category.dart';
import 'package:foora/features/inventory/domain/entities/storage_location.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:foora/shared/components/app_bottom_bar.dart';

class _FakeAiRepository implements AiRepository {
  @override
  Stream<AiAssistantQuota> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  }) => const Stream.empty();

  List<Map<String, dynamic>>? appliedDecisions;

  @override
  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  }) async {
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

Future<void> _openSheet(
  WidgetTester tester,
  AiChatMessage message,
  _FakeAiRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        applyAiActionsProvider.overrideWithValue(ApplyAiActions(repository)),
        foodCategoriesProvider.overrideWith((ref) async => []),
        storageLocationsProvider.overrideWith((ref) async => []),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AiActionReviewSheet(message: message),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

AiChatMessage _proposal(AiAction action) => AiChatMessage(
  id: 'proposal',
  content: 'Phiếu trừ',
  isUser: false,
  timestamp: DateTime(2026),
  actionStatus: 'proposed',
  actions: [action],
);

const _beefBatches = [
  AiActionCandidate(
    itemId: 'later',
    name: 'Thịt bò',
    quantity: 1,
    unit: 'kg',
    expirationDate: '2026-11-02',
  ),
  AiActionCandidate(
    itemId: 'soon',
    name: 'Thịt bò',
    quantity: 0.4,
    unit: 'kg',
    expirationDate: '2026-10-28',
  ),
];

void main() {
  testWidgets('a spoken unit that differs is re-entered, then split by FEFO', (
    tester,
  ) async {
    final repository = _FakeAiRepository();
    await _openSheet(
      tester,
      _proposal(
        const AiAction(
          actionId: 'beef',
          type: 'consume',
          name: 'Thịt bò',
          quantity: 5,
          unit: 'lạng',
          candidateBatches: _beefBatches,
          reviewState: 'needsReview',
          resolution: 'pending',
        ),
      ),
      repository,
    );
    expect(
      find.text(
        'Bạn nói "lạng" nhưng món này lưu theo "kg". '
        'Hãy nhập lại lượng theo kg.',
      ),
      findsOneWidget,
    );
    expect(find.text('Đã dùng · Trong tủ 1.4 kg · 2 lô'), findsOneWidget);
    await tester.tap(find.text('Cập nhật kho (1)'));
    await tester.pump();
    expect(find.text('Nhập số lượng lớn hơn 0.'), findsOneWidget);
    expect(repository.appliedDecisions, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Lượng đã trừ'),
      '0.5',
    );
    await tester.pump();
    expect(find.text('Sau khi trừ còn 0.9 kg'), findsOneWidget);
    expect(
      find.text('0.4 kg từ 28/10/2026, 0.1 kg từ 02/11/2026'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cập nhật kho (1)'));
    await tester.pumpAndSettle();
    expect(repository.appliedDecisions, [
      {
        'actionId': 'beef',
        'accept': true,
        'quantity': 0.5,
        'unit': 'kg',
        'batchAllocations': [
          {'itemId': 'soon', 'quantity': 0.4},
          {'itemId': 'later', 'quantity': 0.1},
        ],
      },
    ]);
  });

  testWidgets('blocks consuming more than the fridge holds', (tester) async {
    final repository = _FakeAiRepository();
    await _openSheet(
      tester,
      _proposal(
        const AiAction(
          actionId: 'beef',
          type: 'consume',
          name: 'Thịt bò',
          quantity: 2,
          unit: 'kg',
          candidateBatches: _beefBatches,
          reviewState: 'needsReview',
          resolution: 'pending',
        ),
      ),
      repository,
    );
    expect(find.text('Vượt quá 0.6 kg so với trong tủ'), findsOneWidget);
    await tester.tap(find.text('Cập nhật kho (1)'));
    await tester.pump();
    expect(find.text('Vượt quá lượng trong tủ (1.4 kg).'), findsOneWidget);
    expect(find.text('Còn 1 mục cần sửa.'), findsOneWidget);
    expect(repository.appliedDecisions, isNull);
  });

  testWidgets('entry editor keeps confirmation visible on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime(2026);
    final message = AiChatMessage(
      id: 'proposal',
      content: 'Phiếu nhập',
      isUser: false,
      timestamp: now,
      actionStatus: 'proposed',
      actions: const [
        AiAction(
          actionId: 'eggs',
          type: 'add_inventory',
          name: 'trứng',
          quantity: 20,
          unit: 'quả',
          candidateBatches: [],
          reviewState: 'needsReview',
          resolution: 'pending',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodCategoriesProvider.overrideWith(
            (ref) async => [
              FoodCategory(
                id: 'dairy_eggs',
                name: 'Trứng & Sữa',
                code: 'DAIRY_EGGS',
                icon: 'egg',
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
            home: Scaffold(body: AiActionReviewSheet(message: message)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sửa phiếu nhập'), findsOneWidget);
    expect(find.text('Món 1 · Thêm vào tủ'), findsOneWidget);
    expect(find.text('Trứng & Sữa'), findsOneWidget);
    expect(find.text('Ngăn mát'), findsOneWidget);
    expect(find.text('Xác nhận nhập kho'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Xác nhận nhập kho')).dy,
      lessThan(700),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('footer uses the inventory form action pair', (tester) async {
    await _openSheet(
      tester,
      _proposal(
        const AiAction(
          actionId: 'beef',
          type: 'consume',
          name: 'Thịt bò',
          quantity: 0.5,
          unit: 'kg',
          candidateBatches: _beefBatches,
          reviewState: 'ready',
          resolution: 'pending',
        ),
      ),
      _FakeAiRepository(),
    );
    final footer = find.byType(AppFormActions);
    expect(footer, findsOneWidget);
    expect(
      find.descendant(of: footer, matching: find.text('Để sau')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: footer, matching: find.text('Cập nhật kho (1)')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: footer, matching: find.byIcon(Icons.save_outlined)),
      findsOneWidget,
    );
    // Same height for both buttons, submit twice as wide as cancel.
    final buttons = find.descendant(
      of: footer,
      matching: find.byType(ElevatedButton),
    );
    final cancel = tester.getSize(buttons.at(0));
    final submit = tester.getSize(buttons.at(1));
    expect(cancel.height, submit.height);
    expect(submit.width, greaterThan(cancel.width * 1.5));

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('Bỏ qua phiếu này'), findsOneWidget);
    expect(
      find.descendant(of: footer, matching: find.byIcon(Icons.block_rounded)),
      findsOneWidget,
    );

    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(find.byType(AiActionReviewSheet), findsNothing);
  });
}
