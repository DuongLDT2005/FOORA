import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/shopping_list_model.dart';
import '../models/shopping_item_model.dart';

abstract class ShoppingRemoteDataSource {
  Stream<List<ShoppingListModel>> watchShoppingLists(String householdId);
  Stream<ShoppingListModel?> watchShoppingList(String householdId, String listId);
  Stream<List<ShoppingItemModel>> watchShoppingItems(String householdId, String listId);

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

  Future<String> addShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String name,
    required double quantity,
    required String unit,
    String? note,
    String? foodId,
  });

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

  Future<void> deleteShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String itemId,
  });

  Future<void> toggleShoppingItemPurchased({
    required String householdId,
    required String shoppingListId,
    required String itemId,
    required bool targetStatus,
  });

  Future<int> importShoppingItemsToInventory({
    required String householdId,
    required String shoppingListId,
    required List<Map<String, dynamic>> items,
  });
}

class ShoppingRemoteDataSourceImpl implements ShoppingRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  ShoppingRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  CollectionReference<Map<String, dynamic>> _listsRef(String householdId) {
    return firestore
        .collection(FirestoreConstants.households)
        .doc(householdId)
        .collection(FirestoreConstants.shoppingLists);
  }

  CollectionReference<Map<String, dynamic>> _itemsRef(
      String householdId, String listId) {
    return _listsRef(householdId).doc(listId).collection(FirestoreConstants.shoppingItems);
  }

  @override
  Stream<List<ShoppingListModel>> watchShoppingLists(String householdId) {
    return _listsRef(householdId)
        .snapshots()
        .map((snapshot) {
          final lists = snapshot.docs
              .map((doc) => ShoppingListModel.fromFirestore(doc, householdId: householdId))
              .toList();
          lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return lists;
        });
  }

  @override
  Stream<ShoppingListModel?> watchShoppingList(String householdId, String listId) {
    return _listsRef(householdId).doc(listId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ShoppingListModel.fromFirestore(doc, householdId: householdId);
    });
  }

  @override
  Stream<List<ShoppingItemModel>> watchShoppingItems(
      String householdId, String listId) {
    return _itemsRef(householdId, listId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ShoppingItemModel.fromFirestore(doc, shoppingListId: listId))
              .toList();
        });
  }

  @override
  Future<String> createShoppingList({
    required String householdId,
    required String name,
    String? note,
    required String createdBy,
  }) async {
    try {
      final docRef = _listsRef(householdId).doc();
      final now = FieldValue.serverTimestamp();
      await docRef.set({
        'name': name.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'createdBy': createdBy,
        'createdAt': now,
        'updatedAt': now,
      });
      return docRef.id;
    } catch (e) {
      throw ServerException('Lỗi tạo danh sách mua sắm: $e');
    }
  }

  @override
  Future<void> updateShoppingList({
    required String householdId,
    required String listId,
    required String name,
    String? note,
  }) async {
    try {
      await _listsRef(householdId).doc(listId).update({
        'name': name.trim(),
        'note': (note != null && note.trim().isNotEmpty) ? note.trim() : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException('Lỗi cập nhật danh sách mua sắm: $e');
    }
  }

  @override
  Future<void> deleteShoppingList({
    required String householdId,
    required String listId,
  }) async {
    try {
      final callable = functions.httpsCallable('deleteShoppingList');
      await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
        'shoppingListId': listId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? 'Lỗi khi xóa danh sách.', e.code);
    } catch (e) {
      throw ServerException('Lỗi khi xóa danh sách: $e');
    }
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
  }) async {
    try {
      final docRef = _itemsRef(householdId, shoppingListId).doc();
      final now = FieldValue.serverTimestamp();
      await docRef.set({
        'name': name.trim(),
        'quantity': quantity,
        'unit': unit.trim(),
        'note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        'foodId': foodId,
        'isPurchased': false,
        'isAddedToInventory': false,
        'inventoryItemId': null,
        'createdAt': now,
        'updatedAt': now,
      });
      return docRef.id;
    } catch (e) {
      throw ServerException('Lỗi thêm món cần mua: $e');
    }
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
  }) async {
    try {
      await _itemsRef(householdId, shoppingListId).doc(itemId).update({
        'name': name.trim(),
        'quantity': quantity,
        'unit': unit.trim(),
        'note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        'foodId': foodId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException('Lỗi cập nhật món: $e');
    }
  }

  @override
  Future<void> deleteShoppingItem({
    required String householdId,
    required String shoppingListId,
    required String itemId,
  }) async {
    try {
      await _itemsRef(householdId, shoppingListId).doc(itemId).delete();
    } catch (e) {
      throw ServerException('Lỗi xóa món cần mua: $e');
    }
  }

  @override
  Future<void> toggleShoppingItemPurchased({
    required String householdId,
    required String shoppingListId,
    required String itemId,
    required bool targetStatus,
  }) async {
    try {
      await _itemsRef(householdId, shoppingListId).doc(itemId).update({
        'isPurchased': targetStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException('Lỗi cập nhật trạng thái đã mua: $e');
    }
  }

  @override
  Future<int> importShoppingItemsToInventory({
    required String householdId,
    required String shoppingListId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final callable = functions.httpsCallable('importShoppingItemsToInventory');
      final response = await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
        'shoppingListId': shoppingListId,
        'items': items,
      });

      final data = response.data;
      final payload = data['data'] as Map<dynamic, dynamic>?;
      return (payload?['addedCount'] as num?)?.toInt() ?? items.length;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw ServerException(
          e.message ??
              'Tủ lạnh đã đạt giới hạn thực phẩm của gói tài khoản. Vui lòng nâng cấp Premium.',
          e.code,
        );
      }
      throw ServerException(e.message ?? 'Lỗi khi nhập thực phẩm vào tủ lạnh.', e.code);
    } catch (e) {
      // In local testing or emulator without functions running, fallback to direct Firestore writes
      AppLogger.w('Functions callable import error, falling back to direct Firestore: $e');
      return await _directImportToInventoryFallback(
        householdId: householdId,
        shoppingListId: shoppingListId,
        items: items,
      );
    }
  }

  Future<int> _directImportToInventoryFallback({
    required String householdId,
    required String shoppingListId,
    required List<Map<String, dynamic>> items,
  }) async {
    int imported = 0;
    final now = DateTime.now();

    for (final item in items) {
      final shoppingItemId = item['shoppingItemId'] as String;
      final name = (item['name'] as String? ?? '').trim();
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final unit = (item['unit'] as String? ?? 'món').trim();
      final locationId = (item['locationId'] as String? ?? 'fridge').trim();
      final categoryId = (item['categoryId'] as String? ?? 'dry').trim();
      final foodId = item['foodId'] as String?;

      final defaultShelfDays = locationId == 'freezer' ? 30 : 7;
      final expirationDate = now.add(Duration(days: defaultShelfDays));

      // 1. Create inventory item doc
      final invRef = firestore
          .collection(FirestoreConstants.households)
          .doc(householdId)
          .collection(FirestoreConstants.inventoryItems)
          .doc();

      await invRef.set({
        'foodId': foodId,
        'name': name,
        'normalizedName': name.toLowerCase(),
        'categoryId': categoryId,
        'quantity': quantity,
        'unit': unit,
        'remainingPercentage': 100,
        'storageLocationId': locationId,
        'purchaseDate': Timestamp.fromDate(now),
        'expirationDate': Timestamp.fromDate(expirationDate),
        'source': 'shopping_list',
        'status': 'active',
        'statusChangedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Mark shopping item as imported
      await firestore
          .collection(FirestoreConstants.households)
          .doc(householdId)
          .collection(FirestoreConstants.shoppingLists)
          .doc(shoppingListId)
          .collection(FirestoreConstants.shoppingItems)
          .doc(shoppingItemId)
          .update({
        'isAddedToInventory': true,
        'inventoryItemId': invRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      imported++;
    }

    return imported;
  }
}
