import '../entities/import_shopping_item_request.dart';
import '../entities/shopping_item.dart';
import '../entities/shopping_item_draft.dart';
import '../entities/shopping_list.dart';
import '../entities/shopping_suggestion.dart';

abstract class ShoppingRepository {
  /// Real-time shopping lists of a household, most recently updated first.
  Stream<List<ShoppingList>> watchShoppingLists(String householdId);

  /// Real-time single list; emits null once it is deleted.
  Stream<ShoppingList?> watchShoppingList(String householdId, String listId);

  /// Real-time items of a list, oldest first.
  Stream<List<ShoppingItem>> watchShoppingItems(
    String householdId,
    String listId,
  );

  Future<String> createShoppingList({
    required String householdId,
    required String name,
    String? note,
    required String createdBy,
  });

  Future<void> updateShoppingList({
    required String householdId,
    required String listId,
    required String name,
    String? note,
  });

  /// Deletes the list and its items (deleteShoppingList callable).
  Future<void> deleteShoppingList({
    required String householdId,
    required String listId,
  });

  /// Adds [draft] or, when a pending item with the same normalized name and
  /// unit exists, increases its quantity atomically.
  Future<AddShoppingItemResult> addShoppingItem({
    required String householdId,
    required String listId,
    required ShoppingItemDraft draft,
    required String normalizedName,
    required String addedBy,
  });

  Future<void> updateShoppingItem({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingItemDraft draft,
    required String normalizedName,
  });

  Future<void> deleteShoppingItem({
    required String householdId,
    required String listId,
    required String itemId,
  });

  Future<void> setItemPurchased({
    required String householdId,
    required String listId,
    required String itemId,
    required bool purchased,
    required String userId,
  });

  /// Moves purchased items into the fridge (importShoppingItemsToInventory
  /// callable). Returns how many inventory batches were created.
  Future<int> importToInventory({
    required String householdId,
    required String listId,
    required List<ImportShoppingItemRequest> items,
  });

  /// "Frequently bought" suggestions (getShoppingSuggestions callable).
  Future<List<ShoppingSuggestion>> getSuggestions(String householdId);
}
