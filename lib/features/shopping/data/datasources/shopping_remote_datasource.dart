import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/import_shopping_item_request.dart';
import '../../domain/entities/shopping_item_draft.dart';
import '../../domain/usecases/validate_shopping_item_draft.dart';
import '../models/shopping_item_model.dart';
import '../models/shopping_list_model.dart';
import '../models/shopping_suggestion_model.dart';

abstract class ShoppingRemoteDataSource {
  Stream<List<ShoppingListModel>> watchShoppingLists(String householdId);
  Stream<ShoppingListModel?> watchShoppingList(
    String householdId,
    String listId,
  );
  Stream<List<ShoppingItemModel>> watchShoppingItems(
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

  Future<void> deleteShoppingList({
    required String householdId,
    required String listId,
  });

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

  Future<int> importToInventory({
    required String householdId,
    required String listId,
    required List<ImportShoppingItemRequest> items,
  });

  Future<List<ShoppingSuggestionModel>> getSuggestions(String householdId);
}

class ShoppingRemoteDataSourceImpl implements ShoppingRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const ShoppingRemoteDataSourceImpl({
    required this.firestore,
    required this.functions,
  });

  CollectionReference<Map<String, dynamic>> _listsRef(String householdId) {
    return firestore
        .collection(FirestoreConstants.households)
        .doc(householdId)
        .collection(FirestoreConstants.shoppingLists);
  }

  CollectionReference<Map<String, dynamic>> _itemsRef(
    String householdId,
    String listId,
  ) {
    return _listsRef(
      householdId,
    ).doc(listId).collection(FirestoreConstants.shoppingItems);
  }

  @override
  Stream<List<ShoppingListModel>> watchShoppingLists(String householdId) {
    return _listsRef(householdId).snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                ShoppingListModel.fromFirestore(doc, householdId: householdId),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  @override
  Stream<ShoppingListModel?> watchShoppingList(
    String householdId,
    String listId,
  ) {
    return _listsRef(householdId).doc(listId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ShoppingListModel.fromFirestore(doc, householdId: householdId);
    });
  }

  @override
  Stream<List<ShoppingItemModel>> watchShoppingItems(
    String householdId,
    String listId,
  ) {
    return _itemsRef(householdId, listId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ShoppingItemModel.fromFirestore(
                  doc,
                  shoppingListId: listId,
                ),
              )
              .toList(),
        );
  }

  @override
  Future<String> createShoppingList({
    required String householdId,
    required String name,
    String? note,
    required String createdBy,
  }) {
    return _guard(() async {
      final docRef = _listsRef(householdId).doc();
      final now = FieldValue.serverTimestamp();
      await docRef.set({
        'name': name,
        'note': note,
        'createdBy': createdBy,
        'createdAt': now,
        'updatedAt': now,
      });
      return docRef.id;
    });
  }

  @override
  Future<void> updateShoppingList({
    required String householdId,
    required String listId,
    required String name,
    String? note,
  }) {
    return _guard(() async {
      await _listsRef(householdId).doc(listId).update({
        'name': name,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> deleteShoppingList({
    required String householdId,
    required String listId,
  }) {
    return _callable('deleteShoppingList', {
      'householdId': householdId,
      'shoppingListId': listId,
    });
  }

  /// Merge rule (PLAN_01 §5.3): a pending item with the same normalized name
  /// and unit gets the extra quantity instead of a duplicate line. The match
  /// is re-read inside a transaction so concurrent edits are not lost.
  @override
  Future<AddShoppingItemResult> addShoppingItem({
    required String householdId,
    required String listId,
    required ShoppingItemDraft draft,
    required String normalizedName,
    required String addedBy,
  }) {
    return _guard(() async {
      final items = _itemsRef(householdId, listId);
      final candidates = await items
          .where('normalizedName', isEqualTo: normalizedName)
          .where('isPurchased', isEqualTo: false)
          .get();
      final unit = draft.unit.toLowerCase();
      final match = candidates.docs
          .where(
            (d) =>
                (d.data()['unit'] as String? ?? '').toLowerCase() == unit &&
                d.data()['isAddedToInventory'] != true,
          )
          .firstOrNull;

      return firestore.runTransaction((tx) async {
        if (match != null) {
          final fresh = await tx.get(match.reference);
          final data = fresh.data();
          final quantity = (data?['quantity'] as num?)?.toDouble() ?? 0;
          final merged = quantity + draft.quantity;
          if (fresh.exists &&
              data?['isPurchased'] == false &&
              merged <= shoppingItemMaxQuantity) {
            tx.update(match.reference, {
              'quantity': merged,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return AddShoppingItemResult(itemId: match.id, merged: true);
          }
        }
        final newRef = items.doc();
        tx.set(
          newRef,
          ShoppingItemModel.newItemData(
            draft: draft,
            normalizedName: normalizedName,
            addedBy: addedBy,
          ),
        );
        return AddShoppingItemResult(itemId: newRef.id, merged: false);
      });
    });
  }

  @override
  Future<void> updateShoppingItem({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingItemDraft draft,
    required String normalizedName,
  }) {
    return _guard(() async {
      await _itemsRef(householdId, listId).doc(itemId).update({
        ...ShoppingItemModel.editableData(
          draft: draft,
          normalizedName: normalizedName,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> deleteShoppingItem({
    required String householdId,
    required String listId,
    required String itemId,
  }) {
    return _guard(() => _itemsRef(householdId, listId).doc(itemId).delete());
  }

  @override
  Future<void> setItemPurchased({
    required String householdId,
    required String listId,
    required String itemId,
    required bool purchased,
    required String userId,
  }) {
    return _guard(() async {
      await _itemsRef(householdId, listId).doc(itemId).update({
        'isPurchased': purchased,
        'purchasedBy': purchased ? userId : null,
        'purchasedAt': purchased ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<int> importToInventory({
    required String householdId,
    required String listId,
    required List<ImportShoppingItemRequest> items,
  }) async {
    final data = await _callable('importShoppingItemsToInventory', {
      'householdId': householdId,
      'shoppingListId': listId,
      'items': [
        for (final item in items)
          {
            'shoppingItemId': item.shoppingItemId,
            'storageLocationId': item.storageLocation.name,
            'categoryId': item.categoryId,
            'actualQuantity': item.actualQuantity,
            if (item.purchaseDate != null)
              'purchaseDate': item.purchaseDate!.toUtc().toIso8601String(),
          },
      ],
    });
    return (data['addedCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<ShoppingSuggestionModel>> getSuggestions(
    String householdId,
  ) async {
    final data = await _callable('getShoppingSuggestions', {
      'householdId': householdId,
    });
    final raw = data['suggestions'] as List<dynamic>? ?? const [];
    return raw
        .map(
          (e) => ShoppingSuggestionModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Calls a FOORA callable and returns its `data` payload.
  Future<Map<String, dynamic>> _callable(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(payload);
      final data = response.data['data'];
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể kết nối máy chủ. Vui lòng thử lại.',
        e.code,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    }
  }
}
