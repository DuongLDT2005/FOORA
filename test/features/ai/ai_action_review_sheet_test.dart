import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/ai/domain/entities/ai_action.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_message.dart';
import 'package:foora/features/ai/presentation/widgets/ai_action_review_sheet.dart';
import 'package:foora/features/inventory/domain/entities/food_category.dart';
import 'package:foora/features/inventory/domain/entities/storage_location.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';

void main() {
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
        child: MaterialApp(
          home: Scaffold(body: AiActionReviewSheet(message: message)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sửa phiếu nhập'), findsOneWidget);
    expect(find.text('Món 1 · trứng'), findsOneWidget);
    expect(find.text('Trứng & Sữa'), findsOneWidget);
    expect(find.text('Ngăn mát'), findsOneWidget);
    expect(find.text('Xác nhận nhập kho'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Xác nhận nhập kho')).dy,
      lessThan(700),
    );
    expect(tester.takeException(), isNull);
  });
}
