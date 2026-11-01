import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/inventory/domain/entities/food_category.dart';
import 'package:foora/features/inventory/domain/entities/inventory_item.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:foora/features/inventory/presentation/widgets/expiration_item_card.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final now = DateTime.now();
  final item = InventoryItem(
    id: 'item-1',
    name: 'Thịt bò',
    normalizedName: 'thit bo',
    categoryId: 'meat',
    quantity: 2,
    unit: 'kg',
    remainingPercentage: 100,
    storageLocationId: 'fridge',
    purchaseDate: now,
    expirationDate: now.add(const Duration(days: 10)),
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    bool isLocked = false,
    VoidCallback? onTap,
    Future<bool> Function()? onConfirmDelete,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodCategoriesProvider.overrideWith(
            (ref) async => const <FoodCategory>[],
          ),
        ],
        child: makeTestableWidget(
          ExpirationItemCard(
            item: item.copyWith(isLocked: isLocked),
            categoryName: 'Thịt',
            storageLocationName: 'Ngăn mát',
            groupType: ExpirationGroupType.safe,
            onTap: onTap ?? () {},
            onConfirmDelete: onConfirmDelete ?? () async => false,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('ExpirationItemCard', () {
    testWidgets('locked item shows the lock badge instead of expiry', (
      tester,
    ) async {
      await pumpCard(tester, isLocked: true);

      expect(find.text('ĐÃ KHÓA'), findsOneWidget);
      expect(find.textContaining('CÒN'), findsNothing);
    });

    testWidgets('unlocked item shows the expiry badge', (tester) async {
      await pumpCard(tester);

      expect(find.text('ĐÃ KHÓA'), findsNothing);
      expect(find.textContaining('CÒN'), findsOneWidget);
    });

    testWidgets('tap opens the item', (tester) async {
      var tapped = 0;
      await pumpCard(tester, onTap: () => tapped++);

      await tester.tap(find.text('Thịt bò'));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('swipe left asks first and keeps the card when declined', (
      tester,
    ) async {
      var asked = 0;
      await pumpCard(
        tester,
        onConfirmDelete: () async {
          asked++;
          return false;
        },
      );

      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(asked, 1);
      expect(find.text('Thịt bò'), findsOneWidget);
    });
  });
}
