import '../../domain/entities/shopping_list.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../datasources/shopping_remote_datasource.dart';

class ShoppingRepositoryImpl implements ShoppingRepository {
  final ShoppingRemoteDataSource remoteDataSource;

  ShoppingRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<ShoppingList>> watchShoppingLists(String householdId) {
    return remoteDataSource.watchShoppingLists(householdId);
  }

  @override
  Stream<ShoppingList?> watchShoppingList(String householdId, String listId) {
    return remoteDataSource.watchShoppingList(householdId, listId);
  }

  @override
  Stream<List<ShoppingItem>> watchShoppingItems(String householdId, String listId) {
    return remoteDataSource.watchShoppingItems(householdId, listId);
  }

  @override
  Future<String> createShoppingList({
    required String householdId,
    required String name,
    String? note,
    required String createdBy,
  }) {
    return remoteDataSource.createShoppingList(
      householdId: householdId,
      name: name,
      note: note,
      createdBy: createdBy,
    );
  }

  @override
  Future<void> updateShoppingList({
    required String householdId,
    required String listId,
    required String name,
    String? note,
  }) {
    return remoteDataSource.updateShoppingList(
      householdId: householdId,
      listId: listId,
      name: name,
      note: note,
    );
  }

  @override
  Future<void> deleteShoppingList({
    required String householdId,
    required String listId,
  }) {
    return remoteDataSource.deleteShoppingList(
      householdId: householdId,
      listId: listId,
    );
  }

  @override
  Future<String> addShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String name,
    required double quantity,
    required String unit,
    String? note,
    String? foodId,
  }) {
    return remoteDataSource.addShoppingItem(
      householdId: householdId,
      shoppingListId: shoppingListId,
      name: name,
      quantity: quantity,
      unit: unit,
      note: note,
      foodId: foodId,
    );
  }

  @override
  Future<void> updateShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String itemId,
    required String name,
    required double quantity,
    required String unit,
    String? note,
    String? foodId,
  }) {
    return remoteDataSource.updateShoppingItem(
      householdId: householdId,
      shoppingListId: shoppingListId,
      itemId: itemId,
      name: name,
      quantity: quantity,
      unit: unit,
      note: note,
      foodId: foodId,
    );
  }

  @override
  Future<void> deleteShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String itemId,
  }) {
    return remoteDataSource.deleteShoppingItem(
      householdId: householdId,
      shoppingListId: shoppingListId,
      itemId: itemId,
    );
  }

  @override
  Future<void> toggleShoppingItemPurchased({
    required String householdId,
    required String shoppingListId,
    required String itemId,
    required bool targetStatus,
  }) {
    return remoteDataSource.toggleShoppingItemPurchased(
      householdId: householdId,
      shoppingListId: shoppingListId,
      itemId: itemId,
      targetStatus: targetStatus,
    );
  }

  @override
  Future<int> importShoppingItemsToInventory({
    required String householdId,
    required String shoppingListId,
    required List<Map<String, dynamic>> items,
  }) {
    return remoteDataSource.importShoppingItemsToInventory(
      householdId: householdId,
      shoppingListId: shoppingListId,
      items: items,
    );
  }
}
