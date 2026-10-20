import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/string_utils.dart';
import '../../domain/entities/food_suggestion.dart';
import '../../domain/entities/shelf_life_duration.dart';
import '../models/food_category_model.dart';
import '../models/inventory_item_model.dart';
import '../models/storage_location_model.dart';

/// Contract for inventory data access (Firestore + Cloud Functions).
abstract class InventoryRemoteDataSource {
  /// Adds an item; returns the new document id.
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

  /// Overwrites an existing item document.
  Future<void> updateInventoryItem({
    required String householdId,
    required InventoryItemModel item,
  });

  /// Updates the status of several items in one batch write.
  Future<void> batchUpdateInventoryStatus({
    required String householdId,
    required List<String> itemIds,
    required String status,
  });

  /// Real-time stream of active items in a household.
  Stream<List<InventoryItemModel>> watchActiveInventoryItems(
    String householdId,
  );

  /// Loads all food categories.
  Future<List<FoodCategoryModel>> getCategories();

  /// Loads all storage locations.
  Future<List<StorageLocationModel>> getStorageLocations();

  /// Looks up the recommended storage duration: the exact
  /// `shelf_life_rules` entry for [foodId] first, then the category's
  /// `defaultShelfLife`. Returns `null` when neither exists.
  Future<ShelfLifeDuration?> findShelfLife({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
  });

  /// Searches master foods collection and merges with household inventory history
  Future<List<FoodSuggestion>> searchFoodSuggestions({
    required String query,
    String? householdId,
  });
}

/// Firestore / Cloud Functions implementation of [InventoryRemoteDataSource].
class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  List<Map<String, dynamic>>? _cachedMasterFoods;
  ({String householdId, DateTime fetchedAt, List<Map<String, dynamic>> items})?
  _cachedHouseholdHistory;

  InventoryRemoteDataSourceImpl({
    required this.firestore,
    required this.functions,
  });

  /// Calls the `addInventoryItem` callable, which enforces plan limits and
  /// updates household counters inside a server-side transaction.
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
          e.message ??
              'Gói tài khoản đã đạt giới hạn thực phẩm. Vui lòng nâng cấp Premium.',
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

  /// Writes the edited item directly to Firestore.
  @override
  Future<void> updateInventoryItem({
    required String householdId,
    required InventoryItemModel item,
    String? previousStatus,
  }) async {
    try {
      final docRef = firestore
          .collection(FirestoreConstants.households)
          .doc(householdId)
          .collection(FirestoreConstants.inventoryItems)
          .doc(item.id);

      // `createdAt` and `source` are immutable after creation (Firestore rules).
      final data = item.toFirestore()
        ..remove('createdAt')
        ..remove('source');
      data['updatedAt'] = FieldValue.serverTimestamp();

      // Write statusChangedAt whenever status transitions to consumed/discarded.
      final isTerminalStatus =
          item.status == InventoryItemStatus.consumed ||
          item.status == InventoryItemStatus.discarded;
      final statusChanged =
          previousStatus != null && previousStatus != item.status.value;
      if (isTerminalStatus && statusChanged) {
        data['statusChangedAt'] = FieldValue.serverTimestamp();
      } else {
        // Preserve existing value; do not overwrite when status did not change.
        data.remove('statusChangedAt');
      }

      await docRef.update(data);
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi cập nhật thực phẩm: $e');
    }
  }

  /// Uses a [WriteBatch] so all status changes succeed or fail together.
  /// Also writes [statusChangedAt] so that waste statistics can bucket by month.
  @override
  Future<void> batchUpdateInventoryStatus({
    required String householdId,
    required List<String> itemIds,
    required String status,
  }) async {
    if (itemIds.isEmpty) return;

    final isTerminalStatus = status == 'consumed' || status == 'discarded';

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
          if (isTerminalStatus) 'statusChangedAt': FieldValue.serverTimestamp(),
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

  /// Listens to `households/{id}/inventory_items` filtered by active status.
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

  /// Reads the `food_categories` collection.
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

  /// Reads the `storage_locations` collection.
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
  Future<ShelfLifeDuration?> findShelfLife({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
  }) async {
    try {
      // 1. Exact food rule for this storage location.
      if (foodId != null && foodId.isNotEmpty) {
        final ruleSnapshot = await firestore
            .collection(FirestoreConstants.shelfLifeRules)
            .where('foodId', isEqualTo: foodId)
            .where('storageLocationId', isEqualTo: storageLocationId)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
        if (ruleSnapshot.docs.isNotEmpty) {
          return _durationFromMap(ruleSnapshot.docs.first.data());
        }
      }

      // 2. Category default for this storage location.
      if (categoryId.isNotEmpty) {
        final categoryDoc = await firestore
            .collection(FirestoreConstants.foodCategories)
            .doc(categoryId)
            .get();
        final defaultShelfLife =
            categoryDoc.data()?['defaultShelfLife'] as Map<String, dynamic>?;
        final locationRule =
            defaultShelfLife?[storageLocationId] as Map<String, dynamic>?;
        if (locationRule != null) {
          return _durationFromMap(locationRule);
        }
      }
      return null;
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi tải thời hạn bảo quản: $e');
    }
  }

  ShelfLifeDuration _durationFromMap(Map<String, dynamic> data) {
    return ShelfLifeDuration(
      minValue: data['minValue'] as num?,
      maxValue: data['maxValue'] as num?,
      unit: data['unit'] as String?,
    );
  }

  /// Fuzzy search: scores catalogue foods (name, tokens, aliases) and the
  /// household's past items, then returns results sorted by relevance.
  @override
  Future<List<FoodSuggestion>> searchFoodSuggestions({
    required String query,
    String? householdId,
  }) async {
    final query_ = _SuggestionQuery.parse(query);
    if (query_ == null) return [];

    final scoredList = <({FoodSuggestion suggestion, int score})>[];
    final seenNames = <String>{};

    void addIfMatch(FoodSuggestion suggestion, int score) {
      if (score <= 0) return;
      if (seenNames.add(suggestion.name.toLowerCase().trim())) {
        scoredList.add((suggestion: suggestion, score: score));
      }
    }

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
        final name = data['name'] as String? ?? '';
        final aliases =
            (data['aliases'] as List<dynamic>?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            [];

        var highestScore = query_.score(name);
        String? matchedAlias;
        for (final alias in aliases) {
          // Aliases rank slightly below an equally good match on the name.
          final aliasScore = query_.score(alias) - 5;
          if (aliasScore > highestScore) {
            highestScore = aliasScore;
            matchedAlias = alias;
          }
        }

        addIfMatch(
          FoodSuggestion(
            foodId: data['id'] as String? ?? '',
            name: name,
            categoryId: data['categoryId'] as String? ?? '',
            defaultUnit: data['defaultUnit'] as String? ?? 'quả',
            isFromMaster: true,
            matchedAlias: matchedAlias,
            photoUrl: data['photoUrl'] as String?,
          ),
          highestScore,
        );
      }

      // 2. Search in household past inventory items (including consumed items)
      if (householdId != null && householdId.isNotEmpty) {
        for (final data in await _getHouseholdHistory(householdId)) {
          final name = data['name'] as String? ?? '';
          addIfMatch(
            FoodSuggestion(
              foodId: data['foodId'] as String?,
              name: name,
              categoryId: data['categoryId'] as String? ?? '',
              defaultUnit: data['unit'] as String? ?? 'quả',
              isFromMaster: false,
              photoUrl: data['photoUrl'] as String?,
            ),
            query_.score(name) - 10,
          );
        }
      }
    } catch (_) {
      // Return whatever matched before the failure.
    }

    // Best match first; on a tie, the shorter (more generic) name wins.
    scoredList.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.suggestion.name.length.compareTo(b.suggestion.name.length);
    });
    return scoredList.map((e) => e.suggestion).toList();
  }

  /// Household items change rarely while typing, so reuse them briefly
  /// instead of reading 100 documents on every keystroke.
  Future<List<Map<String, dynamic>>> _getHouseholdHistory(
    String householdId,
  ) async {
    final cached = _cachedHouseholdHistory;
    if (cached != null &&
        cached.householdId == householdId &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(minutes: 2)) {
      return cached.items;
    }

    final itemDocs = await firestore
        .collection(FirestoreConstants.households)
        .doc(householdId)
        .collection(FirestoreConstants.inventoryItems)
        .limit(100)
        .get();
    final items = itemDocs.docs.map((d) => d.data()).toList();
    _cachedHouseholdHistory = (
      householdId: householdId,
      fetchedAt: DateTime.now(),
      items: items,
    );
    return items;
  }
}

/// Scores how well a food name matches what the user typed.
///
/// Matching is done word by word from the start of each word, so "gà" finds
/// "Thịt gà" but not "Gạo". Matches that keep the Vietnamese accents rank
/// above accent-insensitive ones, so "cá" puts "Cá thu" before "Cà chua".
class _SuggestionQuery {
  final String accented;
  final String plain;
  final List<String> accentedWords;
  final List<String> plainWords;

  _SuggestionQuery._(
    this.accented,
    this.plain,
    this.accentedWords,
    this.plainWords,
  );

  static final _wordSeparator = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static List<String> _words(String text) =>
      text.split(_wordSeparator).where((w) => w.isNotEmpty).toList();

  static _SuggestionQuery? parse(String query) {
    final accentedWords = _words(query.toLowerCase());
    final plainWords = _words(StringUtils.normalize(query));
    if (accentedWords.isEmpty || plainWords.isEmpty) return null;
    return _SuggestionQuery._(
      accentedWords.join(' '),
      plainWords.join(' '),
      accentedWords,
      plainWords,
    );
  }

  /// Every query word must be the start of some word in the candidate.
  static bool _allWordsMatch(List<String> query, List<String> candidate) =>
      query.every((q) => candidate.any((w) => w.startsWith(q)));

  /// 0 means no match.
  int score(String candidate) {
    final accentedWordsC = _words(candidate.toLowerCase());
    final plainWordsC = _words(StringUtils.normalize(candidate));
    final accentedC = accentedWordsC.join(' ');
    final plainC = plainWordsC.join(' ');

    // Any match with the right accents beats every accent-insensitive one.
    if (accentedC == accented) return 120;
    if (accentedC.startsWith(accented)) return 110;
    if (_allWordsMatch(accentedWords, accentedWordsC)) return 100;
    if (plainC == plain) return 90;
    if (plainC.startsWith(plain)) return 85;
    if (_allWordsMatch(plainWords, plainWordsC)) return 65;
    return 0;
  }
}
