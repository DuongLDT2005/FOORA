import 'dart:async';

import 'package:foora/features/shopping/domain/entities/import_shopping_item_request.dart';
import 'package:foora/features/shopping/domain/entities/shopping_item.dart';
import 'package:foora/features/shopping/domain/entities/shopping_item_draft.dart';
import 'package:foora/features/shopping/domain/entities/shopping_list.dart';
import 'package:foora/features/shopping/domain/entities/shopping_suggestion.dart';
import 'package:foora/features/shopping/domain/repositories/shopping_repository.dart';

class AddedItemCall {
  final ShoppingItemDraft draft;
  final String normalizedName;
  final String addedBy;

  const AddedItemCall(this.draft, this.normalizedName, this.addedBy);
}

/// In-memory repository that applies the same merge rule as the Firestore
/// datasource (pending item with the same normalized name and unit).
class FakeShoppingRepository implements ShoppingRepository {
  final List<AddedItemCall> addedItems = [];
  final Map<String, ShoppingItem> _items = {};
  List<ShoppingList> lists = const [];
  List<ShoppingSuggestion> suggestions = const [];
  int _nextId = 0;

  void seedItems(List<ShoppingItem> items) {
    for (final item in items) {
      _items[item.id] = item;
    }
  }

  double quantityOf(String itemId) => _items[itemId]!.quantity;

  @override
  Future<AddShoppingItemResult> addShoppingItem({
    required String householdId,
    required String listId,
    required ShoppingItemDraft draft,
    required String normalizedName,
    required String addedBy,
  }) async {
    addedItems.add(AddedItemCall(draft, normalizedName, addedBy));
    final match = _items.values
        .where(
          (i) =>
              i.shoppingListId == listId &&
              !i.isPurchased &&
              i.normalizedName == normalizedName &&
              i.unit.toLowerCase() == draft.unit.toLowerCase(),
        )
        .firstOrNull;
    final now = DateTime(2026, 10, 1);
    if (match != null) {
      _items[match.id] = ShoppingItem(
        id: match.id,
        shoppingListId: listId,
        name: match.name,
        normalizedName: normalizedName,
        quantity: match.quantity + draft.quantity,
        unit: match.unit,
        createdAt: match.createdAt,
        updatedAt: now,
      );
      return AddShoppingItemResult(itemId: match.id, merged: true);
    }
    final id = 'item-${_nextId++}';
    _items[id] = ShoppingItem(
      id: id,
      shoppingListId: listId,
      name: draft.name,
      normalizedName: normalizedName,
      quantity: draft.quantity,
      unit: draft.unit,
      source: draft.source,
      createdAt: now,
      updatedAt: now,
    );
    return AddShoppingItemResult(itemId: id, merged: false);
  }

  @override
  Stream<List<ShoppingItem>> watchShoppingItems(
    String householdId,
    String listId,
  ) => Stream.value(
    _items.values.where((i) => i.shoppingListId == listId).toList(),
  );

  @override
  Stream<List<ShoppingList>> watchShoppingLists(String householdId) =>
      Stream.value(lists);

  @override
  Stream<ShoppingList?> watchShoppingList(String householdId, String listId) =>
      Stream.value(lists.where((l) => l.id == listId).firstOrNull);

  @override
  Future<List<ShoppingSuggestion>> getSuggestions(String householdId) async =>
      suggestions;

  @override
  Future<String> createShoppingList({
    required String householdId,
    required String name,
    String? note,
    required String createdBy,
  }) async => 'list-new';

  @override
  Future<void> updateShoppingList({
    required String householdId,
    required String listId,
    required String name,
    String? note,
  }) async {}

  @override
  Future<void> deleteShoppingList({
    required String householdId,
    required String listId,
  }) async {}

  @override
  Future<void> updateShoppingItem({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingItemDraft draft,
    required String normalizedName,
  }) async {}

  @override
  Future<void> deleteShoppingItem({
    required String householdId,
    required String listId,
    required String itemId,
  }) async => _items.remove(itemId);

  @override
  Future<void> setItemPurchased({
    required String householdId,
    required String listId,
    required String itemId,
    required bool purchased,
    required String userId,
  }) async {}

  @override
  Future<int> importToInventory({
    required String householdId,
    required String listId,
    required List<ImportShoppingItemRequest> items,
  }) async => items.length;
}
