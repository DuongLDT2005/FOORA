import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/inventory/domain/entities/food_category.dart';
import 'package:foora/features/inventory/domain/entities/food_suggestion.dart';
import 'package:foora/features/inventory/domain/entities/inventory_item.dart';
import 'package:foora/features/inventory/domain/entities/storage_location.dart';
import 'package:foora/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:foora/features/inventory/domain/usecases/add_inventory_item.dart';
import 'package:foora/features/inventory/domain/usecases/get_inventory_items.dart';
import 'package:foora/features/inventory/domain/usecases/update_inventory_item.dart';

class MockInventoryRepository implements InventoryRepository {
  final List<InventoryItem> items = [];
  InventoryItem? lastAddedItem;
  InventoryItem? lastUpdatedItem;
  String? lastHouseholdId;

  @override
  Future<String> addInventoryItem(
    InventoryItem item, {
    required String householdId,
  }) async {
    lastAddedItem = item;
    lastHouseholdId = householdId;
    items.add(item);
    return item.id;
  }

  @override
  Future<void> updateInventoryItem(
    InventoryItem item, {
    required String householdId,
  }) async {
    lastUpdatedItem = item;
    lastHouseholdId = householdId;
    final index = items.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      items[index] = item;
    }
  }

  @override
  Future<void> batchUpdateInventoryStatus({
    required String householdId,
    required List<String> itemIds,
    required InventoryItemStatus status,
  }) async {
    lastHouseholdId = householdId;
    for (var i = 0; i < items.length; i++) {
      if (itemIds.contains(items[i].id)) {
        items[i] = items[i].copyWith(status: status);
      }
    }
  }

  @override
  Stream<List<InventoryItem>> watchActiveInventoryItems(String householdId) {
    return Stream.value(
      items
          .where((element) => element.status == InventoryItemStatus.active)
          .toList(),
    );
  }

  @override
  Future<DateTime> calculateExpiryDate({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  }) async {
    return purchaseDate.add(const Duration(days: 7));
  }

  @override
  Future<
    ({
      DateTime expirationDate,
      num? maxValue,
      num? minValue,
      String? unit,
      bool hasRule,
    })
  >
  calculateExpiryWithRule({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  }) async {
    return (
      expirationDate: purchaseDate.add(const Duration(days: 7)),
      maxValue: 7,
      minValue: 5,
      unit: 'days',
      hasRule: true,
    );
  }

  @override
  Future<List<FoodCategory>> getCategories() async => [];

  @override
  Future<List<StorageLocation>> getStorageLocations() async => [];

  @override
  Future<List<FoodSuggestion>> searchFoodSuggestions({
    required String query,
    String? householdId,
  }) async => [];
}

void main() {
  late MockInventoryRepository mockRepository;
  late AddInventoryItemUseCase addUseCase;
  late UpdateInventoryItemUseCase updateUseCase;
  late GetInventoryItemsUseCase getItemsUseCase;

  final now = DateTime.now();
  final testItem = InventoryItem(
    id: 'item-001',
    name: 'Sữa tươi Tiệt Trùng',
    normalizedName: 'sua tuoi tiet trung',
    categoryId: 'dairy',
    quantity: 2.0,
    unit: 'hộp',
    remainingPercentage: 100,
    storageLocationId: 'fridge',
    purchaseDate: now,
    expirationDate: now.add(const Duration(days: 5)),
    source: InventoryItemSource.manual,
    status: InventoryItemStatus.active,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    mockRepository = MockInventoryRepository();
    addUseCase = AddInventoryItemUseCase(mockRepository);
    updateUseCase = UpdateInventoryItemUseCase(mockRepository);
    getItemsUseCase = GetInventoryItemsUseCase(mockRepository);
  });

  group('Inventory Domain UseCases Tests', () {
    test(
      'AddInventoryItemUseCase should invoke repository and return item id',
      () async {
        final resultId = await addUseCase(testItem, householdId: 'house-123');

        expect(resultId, equals('item-001'));
        expect(mockRepository.lastAddedItem?.id, equals('item-001'));
        expect(mockRepository.lastHouseholdId, equals('house-123'));
      },
    );

    test(
      'UpdateInventoryItemUseCase should pass updated item to repository',
      () async {
        await addUseCase(testItem, householdId: 'house-123');

        final updatedItem = testItem.copyWith(remainingPercentage: 50);
        await updateUseCase(updatedItem, householdId: 'house-123');

        expect(mockRepository.lastUpdatedItem?.remainingPercentage, equals(50));
      },
    );

    test(
      'GetInventoryItemsUseCase should stream active items for household',
      () async {
        await addUseCase(testItem, householdId: 'house-123');

        final stream = getItemsUseCase('house-123');
        final list = await stream.first;

        expect(list.length, equals(1));
        expect(list.first.name, equals('Sữa tươi Tiệt Trùng'));
        expect(list.first.isExpired, isFalse);
      },
    );

    test('InventoryItem isExpired returns true when past expirationDate', () {
      final expiredItem = testItem.copyWith(
        expirationDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiredItem.isExpired, isTrue);
    });
  });
}
