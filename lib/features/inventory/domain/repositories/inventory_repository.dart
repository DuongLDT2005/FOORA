import '../../../../core/constants/app_enums.dart';
import '../entities/food_category.dart';
import '../entities/food_suggestion.dart';
import '../entities/inventory_item.dart';
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

  /// Calculates estimated expiration date dynamically from Firestore:
  /// 1. `shelf_life_rules` matching foodId + storageLocationId
  /// 2. fallback to `food_categories/{categoryId}` defaultShelfLife[storageLocationId]
  /// 3. fallback 3 days (fridge) / 30 days (freezer)
  Future<DateTime> calculateExpiryDate({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  });

  /// Calculates estimated expiration date and returns rule values for UI alert
  Future<({DateTime expirationDate, num? maxValue, num? minValue, String? unit, bool hasRule})>
  calculateExpiryWithRule({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  });

  /// Searches master foods catalog and household past items
  Future<List<FoodSuggestion>> searchFoodSuggestions({
    required String query,
    String? householdId,
  });
}
