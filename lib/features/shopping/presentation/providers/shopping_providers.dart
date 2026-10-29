import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../household/presentation/providers/household_provider.dart';
import '../../data/datasources/shopping_remote_datasource.dart';
import '../../data/repositories/shopping_repository_impl.dart';
import '../../domain/entities/shopping_list.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/repositories/shopping_repository.dart';

// --- Data & Domain Providers ---

final shoppingRemoteDataSourceProvider = Provider<ShoppingRemoteDataSource>((ref) {
  return ShoppingRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(functionsProvider),
  );
});

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepositoryImpl(
    remoteDataSource: ref.watch(shoppingRemoteDataSourceProvider),
  );
});

// --- Stream Providers ---

/// Stream real-time toàn bộ danh sách mua sắm của household hiện tại
final shoppingListsStreamProvider = StreamProvider<List<ShoppingList>>((ref) {
  final householdAsync = ref.watch(currentHouseholdStreamProvider);
  final household = householdAsync.valueOrNull;
  if (household == null || household.id.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(shoppingRepositoryProvider).watchShoppingLists(household.id);
});

/// Alias for active household shopping lists
final activeHouseholdShoppingListsStreamProvider = shoppingListsStreamProvider;

/// Stream chi tiết một Shopping List
final shoppingListDetailStreamProvider =
    StreamProvider.family<ShoppingList?, String>((ref, listId) {
  final householdAsync = ref.watch(currentHouseholdStreamProvider);
  final household = householdAsync.valueOrNull;
  if (household == null || household.id.isEmpty || listId.isEmpty) {
    return Stream.value(null);
  }
  return ref.watch(shoppingRepositoryProvider).watchShoppingList(household.id, listId);
});

/// Alias for single shopping list stream
final shoppingListStreamProvider = shoppingListDetailStreamProvider;

/// Stream danh sách các món trong Shopping List
final shoppingItemsStreamProvider =
    StreamProvider.family<List<ShoppingItem>, String>((ref, listId) {
  final householdAsync = ref.watch(currentHouseholdStreamProvider);
  final household = householdAsync.valueOrNull;
  if (household == null || household.id.isEmpty || listId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(shoppingRepositoryProvider).watchShoppingItems(household.id, listId);
});

/// Tiến độ mua sắm được tính realtime từ items (Section 4 FR-06 & Section 8.1)
/// Trả về (purchasedCount, totalCount)
final shoppingListProgressProvider =
    Provider.family<(int, int), String>((ref, listId) {
  final items = ref.watch(shoppingItemsStreamProvider(listId)).valueOrNull ?? [];
  final total = items.length;
  final purchased = items.where((i) => i.isPurchased).length;
  return (purchased, total);
});

// --- Controller Provider ---

class ShoppingController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  ShoppingController(this.ref) : super(const AsyncValue.data(null));

  ShoppingRepository get _repository => ref.read(shoppingRepositoryProvider);
  String? get _householdId =>
      ref.read(currentHouseholdStreamProvider).valueOrNull?.id ??
      ref.read(currentUserProvider)?.activeHouseholdId;
  String? get _userId => ref.read(currentUserProvider)?.id;

  String _getHouseholdId(String? customHouseholdId) {
    final hId = customHouseholdId ?? _householdId;
    if (hId == null || hId.isEmpty) {
      throw Exception('Bạn chưa chọn gia đình hoạt động.');
    }
    return hId;
  }

  Future<String> createShoppingList({
    String? householdId,
    required String name,
    String? note,
  }) async {
    final hId = _getHouseholdId(householdId);
    state = const AsyncValue.loading();
    try {
      final listId = await _repository.createShoppingList(
        householdId: hId,
        name: name,
        note: note,
        createdBy: _userId ?? '',
      );
      state = const AsyncValue.data(null);
      return listId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateShoppingList({
    String? householdId,
    required String listId,
    required String name,
    String? note,
  }) async {
    final hId = _getHouseholdId(householdId);
    state = const AsyncValue.loading();
    try {
      await _repository.updateShoppingList(
        householdId: hId,
        listId: listId,
        name: name,
        note: note,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteShoppingList(String listId, {String? householdId}) async {
    final hId = _getHouseholdId(householdId);
    state = const AsyncValue.loading();
    try {
      await _repository.deleteShoppingList(
        householdId: hId,
        listId: listId,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> addShoppingItem({
    String? householdId,
    required String listId,
    required String name,
    required double quantity,
    required String unit,
    String? note,
    String? foodId,
  }) async {
    final hId = _getHouseholdId(householdId);
    state = const AsyncValue.loading();
    try {
      final id = await _repository.addShoppingItem(
        householdId: hId,
        shoppingListId: listId,
        name: name,
        quantity: quantity,
        unit: unit,
        note: note,
        foodId: foodId,
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateShoppingItem({
    String? householdId,
    required String listId,
    required String itemId,
    required String name,
    required double quantity,
    required String unit,
    String? note,
    String? foodId,
  }) async {
    final hId = _getHouseholdId(householdId);
    state = const AsyncValue.loading();
    try {
      await _repository.updateShoppingItem(
        householdId: hId,
        shoppingListId: listId,
        itemId: itemId,
        name: name,
        quantity: quantity,
        unit: unit,
        note: note,
        foodId: foodId,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteShoppingItem(
    String listId,
    String itemId, {
    String? householdId,
  }) async {
    final hId = _getHouseholdId(householdId);
    state = const AsyncValue.loading();
    try {
      await _repository.deleteShoppingItem(
        householdId: hId,
        shoppingListId: listId,
        itemId: itemId,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> togglePurchased(
    String listId,
    ShoppingItem item, {
    String? householdId,
  }) async {
    return toggleShoppingItemPurchased(
      householdId: householdId,
      shoppingListId: listId,
      itemId: item.id,
      targetStatus: !item.isPurchased,
    );
  }

  Future<void> toggleShoppingItemPurchased({
    String? householdId,
    required String shoppingListId,
    required String itemId,
    required bool targetStatus,
  }) async {
    final hId = _getHouseholdId(householdId);
    state = const AsyncValue.loading();
    try {
      await _repository.toggleShoppingItemPurchased(
        householdId: hId,
        shoppingListId: shoppingListId,
        itemId: itemId,
        targetStatus: targetStatus,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<int> importShoppingItemsToInventory({
    String? householdId,
    required String listId,
    required List<Map<String, dynamic>> items,
  }) async {
    final hId = _getHouseholdId(householdId);
    state = const AsyncValue.loading();
    try {
      final addedCount = await _repository.importShoppingItemsToInventory(
        householdId: hId,
        shoppingListId: listId,
        items: items,
      );
      state = const AsyncValue.data(null);
      return addedCount;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final shoppingControllerProvider =
    StateNotifierProvider<ShoppingController, AsyncValue<void>>((ref) {
  return ShoppingController(ref);
});
