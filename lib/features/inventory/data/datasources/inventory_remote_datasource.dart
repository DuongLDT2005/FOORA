import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/string_utils.dart';
import '../../domain/entities/food_suggestion.dart';
import '../models/food_category_model.dart';
import '../models/inventory_item_model.dart';
import '../models/storage_location_model.dart';

abstract class InventoryRemoteDataSource {
  Future<String> addInventoryItem({
    required String householdId,
    required String name,
    String? foodId,
    required String categoryId,
    required double quantity,
    required String unit,
    required String storageLocationId,
    required DateTime purchaseDate,
    DateTime? expirationDate,
    String? photoUrl,
    String? source,
  });

  Future<void> updateInventoryItem({
    required String householdId,
    required InventoryItemModel item,
  });

  Future<void> batchUpdateInventoryStatus({
    required String householdId,
    required List<String> itemIds,
    required String status,
  });

  Stream<List<InventoryItemModel>> watchActiveInventoryItems(
    String householdId,
  );

  Future<List<FoodCategoryModel>> getCategories();

  Future<List<StorageLocationModel>> getStorageLocations();

  Future<DateTime> calculateExpiryDate({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  });

  /// Calculates expiration date with max rule parameters (maxValue, unit) for UI display
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
  });

  /// Searches master foods collection and merges with household inventory history
  Future<List<FoodSuggestion>> searchFoodSuggestions({
    required String query,
    String? householdId,
  });
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  List<Map<String, dynamic>>? _cachedMasterFoods;

  InventoryRemoteDataSourceImpl({
    required this.firestore,
    required this.functions,
  });

  @override
  Future<String> addInventoryItem({
    required String householdId,
    required String name,
    String? foodId,
    required String categoryId,
    required double quantity,
    required String unit,
    required String storageLocationId,
    required DateTime purchaseDate,
    DateTime? expirationDate,
    String? photoUrl,
    String? source,
  }) async {
    try {
      final callable = functions.httpsCallable('addInventoryItem');
      final response = await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
        'name': name.trim(),
        'foodId': foodId,
        'categoryId': categoryId,
        'quantity': quantity,
        'unit': unit.trim(),
        'storageLocationId': storageLocationId,
        'purchaseDate': purchaseDate.toIso8601String(),
        'expirationDate': expirationDate?.toIso8601String(),
        'photoUrl': photoUrl,
        'source': source ?? 'manual',
      });

      final data = response.data;
      final itemData = data['data'] as Map<dynamic, dynamic>?;
      final itemId = itemData?['itemId'] as String?;
      if (itemId == null || itemId.isEmpty) {
        throw const ServerException('Không nhận được mã thực phẩm từ máy chủ.');
      }
      return itemId;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw ServerException(
          e.message ?? 'Gói tài khoản đã đạt giới hạn thực phẩm. Vui lòng nâng cấp Premium.',
          e.code,
        );
      }
      throw ServerException(
        e.message ?? 'Lỗi thực thi thêm thực phẩm trên máy chủ.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi không xác định khi thêm thực phẩm: $e');
    }
  }

  @override
  Future<void> updateInventoryItem({
    required String householdId,
    required InventoryItemModel item,
  }) async {
    try {
      final docRef = firestore
          .collection(FirestoreConstants.households)
          .doc(householdId)
          .collection(FirestoreConstants.inventoryItems)
          .doc(item.id);

      final data = item.toFirestore();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.update(data);
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi cập nhật thực phẩm: $e');
    }
  }

  @override
  Future<void> batchUpdateInventoryStatus({
    required String householdId,
    required List<String> itemIds,
    required String status,
  }) async {
    if (itemIds.isEmpty) return;

    try {
      final batch = firestore.batch();
      final itemsRef = firestore
          .collection(FirestoreConstants.households)
          .doc(householdId)
          .collection(FirestoreConstants.inventoryItems);

      for (final itemId in itemIds) {
        final docRef = itemsRef.doc(itemId);
        batch.update(docRef, {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi cập nhật hàng loạt: $e');
    }
  }

  @override
  Stream<List<InventoryItemModel>> watchActiveInventoryItems(
    String householdId,
  ) {
    return firestore
        .collection(FirestoreConstants.households)
        .doc(householdId)
        .collection(FirestoreConstants.inventoryItems)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => InventoryItemModel.fromFirestore(doc))
              .toList();
        });
  }

  @override
  Future<List<FoodCategoryModel>> getCategories() async {
    try {
      final snapshot = await firestore
          .collection(FirestoreConstants.foodCategories)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => FoodCategoryModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi tải danh mục thực phẩm: $e');
    }
  }

  @override
  Future<List<StorageLocationModel>> getStorageLocations() async {
    try {
      final snapshot = await firestore
          .collection(FirestoreConstants.storageLocations)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => StorageLocationModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi tải vị trí bảo quản: $e');
    }
  }

  @override
  Future<DateTime> calculateExpiryDate({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  }) async {
    final result = await calculateExpiryWithRule(
      foodId: foodId,
      categoryId: categoryId,
      storageLocationId: storageLocationId,
      purchaseDate: purchaseDate,
    );
    return result.expirationDate;
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
    try {
      num? durationValue;
      num? minValue;
      String? durationUnit;
      bool hasStandardRule = false;

      // 1. Query exact match in shelf_life_rules if foodId is present
      if (foodId != null && foodId.isNotEmpty) {
        final ruleSnapshot = await firestore
            .collection(FirestoreConstants.shelfLifeRules)
            .where('foodId', isEqualTo: foodId)
            .where('storageLocationId', isEqualTo: storageLocationId)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (ruleSnapshot.docs.isNotEmpty) {
          final data = ruleSnapshot.docs.first.data();
          durationValue = data['maxValue'] ?? data['minValue'];
          minValue = data['minValue'];
          durationUnit = data['unit'] as String?;
          hasStandardRule = durationValue != null && durationUnit != null;
        }
      }

      // 2. Fallback to defaultShelfLife in food_categories/{categoryId}
      if (!hasStandardRule && categoryId.isNotEmpty) {
        final catDoc = await firestore
            .collection(FirestoreConstants.foodCategories)
            .doc(categoryId)
            .get();

        if (catDoc.exists) {
          final data = catDoc.data();
          final defaultShelfLife = data?['defaultShelfLife'] as Map?;
          final locRule = defaultShelfLife?[storageLocationId] as Map?;
          if (locRule != null) {
            durationValue = locRule['maxValue'] ?? locRule['minValue'];
            minValue = locRule['minValue'];
            durationUnit = locRule['unit'] as String?;
            hasStandardRule = durationValue != null && durationUnit != null;
          }
        }
      }

      // 3. Fallback default if still not determined
      final effectiveValue =
          (durationValue ?? (storageLocationId == 'freezer' ? 30 : 3)).toInt();
      final effectiveUnit = durationUnit ?? 'days';

      DateTime calculatedDate;
      switch (effectiveUnit) {
        case 'days':
          calculatedDate = purchaseDate.add(Duration(days: effectiveValue));
          break;
        case 'weeks':
          calculatedDate = purchaseDate.add(Duration(days: effectiveValue * 7));
          break;
        case 'months':
          calculatedDate = DateTime(
            purchaseDate.year,
            purchaseDate.month + effectiveValue,
            purchaseDate.day,
          );
          break;
        case 'years':
          calculatedDate = DateTime(
            purchaseDate.year + effectiveValue,
            purchaseDate.month,
            purchaseDate.day,
          );
          break;
        default:
          calculatedDate = purchaseDate.add(Duration(days: effectiveValue));
      }

      return (
        expirationDate: calculatedDate,
        maxValue: hasStandardRule ? durationValue : null,
        minValue: hasStandardRule ? minValue : null,
        unit: hasStandardRule ? durationUnit : null,
        hasRule: hasStandardRule,
      );
    } catch (_) {
      final fallbackDays = storageLocationId == 'freezer' ? 30 : 3;
      return (
        expirationDate: purchaseDate.add(Duration(days: fallbackDays)),
        maxValue: null,
        minValue: null,
        unit: null,
        hasRule: false,
      );
    }
  }

  @override
  Future<List<FoodSuggestion>> searchFoodSuggestions({
    required String query,
    String? householdId,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final normalizedQuery = StringUtils.normalize(cleanQuery);
    final queryTokens = normalizedQuery
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    if (queryTokens.isEmpty) return [];

    // Helper data structure for scoring & sorting
    final scoredList = <({FoodSuggestion suggestion, int score})>[];
    final seenNames = <String>{};

    try {
      // 1. Fetch & cache master `foods` collection
      if (_cachedMasterFoods == null) {
        final foodDocs = await firestore
            .collection(FirestoreConstants.foods)
            .where('isActive', isEqualTo: true)
            .get();

        _cachedMasterFoods = foodDocs.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      }

      for (final data in _cachedMasterFoods!) {
        final docId = data['id'] as String? ?? '';
        final name = data['name'] as String? ?? '';
        final normalizedName =
            (data['normalizedName'] as String? ?? '').isNotEmpty
            ? (data['normalizedName'] as String)
            : StringUtils.normalize(name);
        final aliases =
            (data['aliases'] as List<dynamic>?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            [];

        int highestScore = 0;
        String? matchedAlias;

        // Score against standard name
        if (normalizedName == normalizedQuery) {
          highestScore = 100; // Exact match
        } else if (normalizedName.startsWith(normalizedQuery)) {
          highestScore = 85; // Starts with full query
        } else if (normalizedName.contains(normalizedQuery)) {
          highestScore = 70; // Contains full query
        } else {
          // Token-based matching on name (e.g. "thịt heo" matches "thịt lợn nạc heo")
          final allTokensMatch = queryTokens.every(
            (t) => normalizedName.contains(t),
          );
          if (allTokensMatch) {
            highestScore = 55;
          } else {
            final anyTokenMatch = queryTokens.any(
              (t) => normalizedName.contains(t),
            );
            if (anyTokenMatch) {
              highestScore = 20;
            }
          }
        }

        // Score against aliases
        for (final alias in aliases) {
          final normAlias = StringUtils.normalize(alias);
          int aliasScore = 0;
          if (normAlias == normalizedQuery) {
            aliasScore = 95;
          } else if (normAlias.startsWith(normalizedQuery)) {
            aliasScore = 80;
          } else if (normAlias.contains(normalizedQuery)) {
            aliasScore = 65;
          } else if (queryTokens.every((t) => normAlias.contains(t))) {
            aliasScore = 50;
          }

          if (aliasScore > highestScore) {
            highestScore = aliasScore;
            matchedAlias = alias;
          }
        }

        if (highestScore > 0) {
          final lower = name.toLowerCase().trim();
          if (!seenNames.contains(lower)) {
            seenNames.add(lower);
            scoredList.add((
              suggestion: FoodSuggestion(
                foodId: docId,
                name: name,
                categoryId: data['categoryId'] as String? ?? '',
                defaultUnit: data['defaultUnit'] as String? ?? 'quả',
                isFromMaster: true,
                matchedAlias: matchedAlias,
                photoUrl: data['photoUrl'] as String?,
              ),
              score: highestScore,
            ));
          }
        }
      }

      // 2. Search in household past inventory items (including consumed items)
      if (householdId != null && householdId.isNotEmpty) {
        final itemDocs = await firestore
            .collection(FirestoreConstants.households)
            .doc(householdId)
            .collection(FirestoreConstants.inventoryItems)
            .limit(100)
            .get();

        for (final doc in itemDocs.docs) {
          final data = doc.data();
          final name = data['name'] as String? ?? '';
          final normalizedName =
              (data['normalizedName'] as String? ?? '').isNotEmpty
              ? (data['normalizedName'] as String)
              : StringUtils.normalize(name);

          int itemScore = 0;
          if (normalizedName == normalizedQuery) {
            itemScore = 90;
          } else if (normalizedName.startsWith(normalizedQuery)) {
            itemScore = 75;
          } else if (normalizedName.contains(normalizedQuery)) {
            itemScore = 60;
          } else if (queryTokens.every((t) => normalizedName.contains(t))) {
            itemScore = 45;
          }

          if (itemScore > 0) {
            final lower = name.toLowerCase().trim();
            if (!seenNames.contains(lower)) {
              seenNames.add(lower);
              scoredList.add((
                suggestion: FoodSuggestion(
                  foodId: data['foodId'] as String?,
                  name: name,
                  categoryId: data['categoryId'] as String? ?? '',
                  defaultUnit: data['unit'] as String? ?? 'quả',
                  isFromMaster: false,
                  photoUrl: data['photoUrl'] as String?,
                ),
                score: itemScore,
              ));
            }
          }
        }
      }

      // Sort by relevance score descending
      scoredList.sort((a, b) => b.score.compareTo(a.score));

      return scoredList.map((e) => e.suggestion).toList();
    } catch (_) {
      return scoredList.map((e) => e.suggestion).toList();
    }
  }
}
