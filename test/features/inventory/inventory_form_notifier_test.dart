import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/inventory/domain/entities/food_category.dart';
import 'package:foora/features/inventory/domain/entities/inventory_item.dart';
import 'package:foora/features/inventory/domain/entities/shelf_life_duration.dart';
import 'package:foora/features/inventory/domain/entities/storage_location.dart';
import 'package:foora/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_form_state.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';

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
  });
}
