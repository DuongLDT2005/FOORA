import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/inventory/domain/entities/food_category.dart';
import 'package:foora/features/inventory/domain/entities/inventory_item.dart';
import 'package:foora/features/inventory/domain/entities/shelf_life_duration.dart';
import 'package:foora/features/inventory/domain/entities/storage_location.dart';
import 'package:foora/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:foora/features/inventory/presentation/pages/item_form_page.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_form_state.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';

import '../../helpers/test_helpers.dart';

class _FakeInventoryRepository implements InventoryRepository {
  @override
  Future<ShelfLifeDuration?> findShelfLife({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
  }) async {
    return const ShelfLifeDuration(minValue: 3, maxValue: 5, unit: 'days');
  }

  @override
  Future<List<FoodCategory>> getCategories() async => [
    FoodCategory(
      id: 'meat',
      name: 'Thịt',
      code: 'MEAT',
      icon: 'lucide-beef',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  Future<List<StorageLocation>> getStorageLocations() async => [
    StorageLocation(
      id: 'fridge',
      name: 'Ngăn mát',
      code: StorageLocationCode.fridge,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    StorageLocation(
      id: 'freezer',
      name: 'Ngăn đông',
      code: StorageLocationCode.freezer,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final purchaseDate = DateTime(2026, 10, 1);
  // Differs from the 5-day estimate, as a date the user edited would.
  final storedExpiration = DateTime(2026, 12, 25);

  final storedItem = InventoryItem(
    id: 'item-1',
    foodId: 'beef',
    name: 'Thịt bò',
    normalizedName: 'thit bo',
    categoryId: 'meat',
    quantity: 2,
    initialQuantity: 4,
    unit: 'kg',
    remainingPercentage: 50,
    storageLocationId: 'fridge',
    purchaseDate: purchaseDate,
    expirationDate: storedExpiration,
    createdAt: purchaseDate,
    updatedAt: purchaseDate,
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(
          _FakeInventoryRepository(),
        ),
        activeHouseholdInventoryStreamProvider.overrideWith(
          (ref) => Stream.value(const <InventoryItem>[]),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Opens the form and lets metadata + shelf-life lookups finish.
  Future<InventoryFormState> openForm(InventoryItem? item) async {
    container.listen(inventoryFormNotifierProvider(item), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return container.read(inventoryFormNotifierProvider(item));
  }

  group('InventoryFormNotifier', () {
    test('edit form shows the stored item instead of food defaults', () async {
      final state = await openForm(storedItem);

      expect(state.expirationDate, storedExpiration);
      expect(state.purchaseDate, purchaseDate);
      expect(state.name, 'Thịt bò');
      expect(state.categoryId, 'meat');
      expect(state.storageLocationId, 'fridge');
      expect(state.quantity, 2);
      expect(state.initialQuantity, 4);
      expect(state.unit, 'kg');
      expect(state.remainingPercentage, 50);
    });

    test('edit form still loads the shelf-life hint', () async {
      final state = await openForm(storedItem);

      expect(state.hasShelfLifeRule, isTrue);
      expect(state.maxStorageTime, 5);
      expect(state.storageTimeUnit, 'days');
    });

    test(
      'edit form re-estimates expiry when the user moves the item',
      () async {
        await openForm(storedItem);

        await container
            .read(inventoryFormNotifierProvider(storedItem).notifier)
            .onLocationChanged('freezer');

        expect(
          container
              .read(inventoryFormNotifierProvider(storedItem))
              .expirationDate,
          purchaseDate.add(const Duration(days: 5)),
        );
      },
    );

    test('create form still estimates the expiry date', () async {
      final state = await openForm(null);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(state.expirationDate, today.add(const Duration(days: 5)));
      expect(state.hasShelfLifeRule, isTrue);
    });

    test('slider moves the quantity and keeps the batch size', () async {
      await openForm(storedItem);
      final provider = inventoryFormNotifierProvider(storedItem);

      container.read(provider.notifier).onRemainingPercentageChanged(30);

      final state = container.read(provider);
      expect(state.quantity, 1.2);
      expect(state.initialQuantity, 4);
      expect(state.remainingPercentage, 30);
    });

    test('create form keeps the batch size when the slider moves', () async {
      await openForm(null);
      final provider = inventoryFormNotifierProvider(null);
      final notifier = container.read(provider.notifier);

      notifier.onQuantityChanged(10);
      notifier.onRemainingPercentageChanged(50);
      // The text field echoes the slider's quantity back to the notifier.
      notifier.onQuantityChanged(5);

      final state = container.read(provider);
      expect(state.quantity, 5);
      expect(state.initialQuantity, 10);
      expect(state.remainingPercentage, 50);
    });

    test('typing a new quantity on the create form resets the batch', () async {
      await openForm(null);
      final provider = inventoryFormNotifierProvider(null);
      final notifier = container.read(provider.notifier);

      notifier.onQuantityChanged(10);
      notifier.onRemainingPercentageChanged(50);
      notifier.onQuantityChanged(8);

      final state = container.read(provider);
      expect(state.quantity, 8);
      expect(state.initialQuantity, 8);
      expect(state.remainingPercentage, 100);
    });
  });

  group('ItemFormPage', () {
    testWidgets('slider updates the quantity field and shows the batch size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget(ItemFormPage(itemToEdit: storedItem)),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Số lượng ban đầu: 4 kg'), findsOneWidget);

      await tester.ensureVisible(find.byType(Slider));
      await tester.pump();
      await tester.drag(find.byType(Slider), const Offset(-1000, 0));
      await tester.pump();

      expect(find.text('0%'), findsOneWidget);
      expect(find.widgetWithText(TextField, '0'), findsOneWidget);
      expect(find.text('Số lượng ban đầu: 4 kg'), findsOneWidget);
      final state = container.read(inventoryFormNotifierProvider(storedItem));
      expect(state.quantity, 0);
      expect(state.initialQuantity, 4);
    });
  });
}
