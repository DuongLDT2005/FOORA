import '../../../../core/constants/app_enums.dart';
import '../entities/food_category.dart';
import '../entities/food_suggestion.dart';
import '../entities/inventory_item.dart';
import '../entities/shelf_life_duration.dart';
import '../entities/storage_location.dart';

abstract class InventoryRepository {
  /// Calls Firebase Callable Cloud Function `addInventoryItem`
  Future<String> addInventoryItem(
    InventoryItem item, {
    required String householdId,
  });

  /// Direct Firestore update for item in `households/{householdId}/inventory_items/{itemId}`
  Future<void> updateInventoryItem(
    InventoryItem item, {
    required String householdId,
  });

  /// Batch update status for multiple items in `households/{householdId}/inventory_items`
  Future<void> batchUpdateInventoryStatus({
    required String householdId,
    required List<String> itemIds,
    required InventoryItemStatus status,
  });

  /// Streams active inventory items for smart alert & inventory list
  Stream<List<InventoryItem>> watchActiveInventoryItems(String householdId);

  /// Retrieves active food categories from `food_categories`
  Future<List<FoodCategory>> getCategories();

  /// Retrieves active storage locations from `storage_locations`
  Future<List<StorageLocation>> getStorageLocations();

  /// Recommended storage duration for a food at a storage location:
  /// exact `shelf_life_rules` entry first, then the category default.
  /// Returns `null` when no recommendation exists.
  Future<ShelfLifeDuration?> findShelfLife({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
  });

  /// Searches master foods catalog and household past items
  Future<List<FoodSuggestion>> searchFoodSuggestions({
    required String query,
    String? householdId,
  });
}
