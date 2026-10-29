import '../entities/shopping_list.dart';
import '../entities/shopping_item.dart';

abstract class ShoppingRepository {
  /// Stream real-time danh sách các Shopping Lists của Household
  Stream<List<ShoppingList>> watchShoppingLists(String householdId);

  /// Stream real-time một Shopping List cụ thể
  Stream<ShoppingList?> watchShoppingList(String householdId, String listId);

  /// Stream real-time danh sách món trong subcollection items
  Stream<List<ShoppingItem>> watchShoppingItems(String householdId, String listId);

  /// Tạo mới Shopping List
  Future<String> createShoppingList({
    required String householdId,
    required String name,
    String? note,
    required String createdBy,
  });

  /// Chỉnh sửa tên danh sách
  Future<void> updateShoppingList({
    required String householdId,
    required String listId,
    required String name,
    String? note,
  });

  /// Xóa danh sách (Qua Cloud Function deleteShoppingList)
  Future<void> deleteShoppingList({
    required String householdId,
    required String listId,
  });

  /// Thêm món vào danh sách
  Future<String> addShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String name,
    required double quantity,
    required String unit,
    String? note,
    String? foodId,
  });

  /// Chỉnh sửa thông tin món
  Future<void> updateShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String itemId,
    required String name,
    required double quantity,
    required String unit,
    String? note,
    String? foodId,
  });

  /// Xóa món khỏi danh sách
  Future<void> deleteShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String itemId,
  });

  /// Tick / Bỏ tick đã mua
  Future<void> toggleShoppingItemPurchased({
    required String householdId,
    required String shoppingListId,
    required String itemId,
    required bool targetStatus,
  });

  /// Nhập các món đã mua vào tủ lạnh (Qua Cloud Function importShoppingItemsToInventory)
  Future<int> importShoppingItemsToInventory({
    required String householdId,
    required String shoppingListId,
    required List<Map<String, dynamic>> items,
  });
}
