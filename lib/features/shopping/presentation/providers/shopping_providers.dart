import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/domain/entities/food_suggestion.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../data/datasources/shopping_remote_datasource.dart';
import '../../data/repositories/shopping_repository_impl.dart';
import '../../domain/entities/import_shopping_item_request.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_item_draft.dart';
import '../../domain/entities/shopping_list.dart';
import '../../domain/entities/shopping_suggestion.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../../domain/usecases/add_shopping_item.dart';
import '../../domain/usecases/delete_shopping_item.dart';
import '../../domain/usecases/delete_shopping_list.dart';
import '../../domain/usecases/get_shopping_suggestions.dart';
import '../../domain/usecases/import_shopping_items_to_inventory.dart';
import '../../domain/usecases/parse_voice_shopping_text.dart';
import '../../domain/usecases/save_shopping_list.dart';
import '../../domain/usecases/set_shopping_item_purchased.dart';
import '../../domain/usecases/update_shopping_item.dart';
import '../../domain/usecases/watch_shopping_items.dart';
import '../../domain/usecases/watch_shopping_list.dart';
import '../../domain/usecases/watch_shopping_lists.dart';

// --- Data & Domain Providers ---

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepositoryImpl(
    remoteDataSource: ShoppingRemoteDataSourceImpl(
      firestore: ref.watch(firestoreProvider),
      functions: ref.watch(functionsProvider),
    ),
  );
});

final parseVoiceShoppingTextProvider = Provider(
  (ref) => const ParseVoiceShoppingTextUseCase(),
);

/// Active household of the signed-in user; lists follow it when the user
/// switches or leaves a household.
final _activeHouseholdIdProvider = Provider<String?>((ref) {
  final id = ref.watch(currentUserProvider)?.activeHouseholdId;
  return id == null || id.isEmpty ? null : id;
});

/// Shopping lists belong to a household, so other features (the AI recipe
/// card) only offer "add to shopping list" when one is active.
final canUseShoppingListsProvider = Provider<bool>(
  (ref) => ref.watch(_activeHouseholdIdProvider) != null,
);

// --- Streams ---

final shoppingListsStreamProvider =
    StreamProvider.autoDispose<List<ShoppingList>>((ref) {
      final householdId = ref.watch(_activeHouseholdIdProvider);
      if (householdId == null) return Stream.value(const []);
      return WatchShoppingListsUseCase(ref.watch(shoppingRepositoryProvider))(
        householdId,
      );
    });

final shoppingListStreamProvider = StreamProvider.autoDispose
    .family<ShoppingList?, String>((ref, listId) {
      final householdId = ref.watch(_activeHouseholdIdProvider);
      if (householdId == null) return Stream.value(null);
      return WatchShoppingListUseCase(ref.watch(shoppingRepositoryProvider))(
        householdId,
        listId,
      );
    });

final shoppingItemsStreamProvider = StreamProvider.autoDispose
    .family<List<ShoppingItem>, String>((ref, listId) {
      final householdId = ref.watch(_activeHouseholdIdProvider);
      if (householdId == null) return Stream.value(const []);
      return WatchShoppingItemsUseCase(ref.watch(shoppingRepositoryProvider))(
        householdId,
        listId,
      );
    });

/// (purchased, total) for a list, computed from its items.
final shoppingListProgressProvider = Provider.autoDispose
    .family<(int, int), String>((ref, listId) {
      final items =
          ref.watch(shoppingItemsStreamProvider(listId)).valueOrNull ??
          const <ShoppingItem>[];
      return (items.where((i) => i.isPurchased).length, items.length);
    });

/// "Frequently bought" suggestions; refresh with `ref.invalidate`.
final shoppingSuggestionsProvider =
    FutureProvider.autoDispose<List<ShoppingSuggestion>>((ref) {
      final householdId = ref.watch(_activeHouseholdIdProvider);
      if (householdId == null) return Future.value(const []);
      return GetShoppingSuggestionsUseCase(
        ref.watch(shoppingRepositoryProvider),
      )(householdId);
    });

// --- Commands ---

/// Coordinates shopping use cases for the UI. Errors are rethrown as
/// [Failure]s (or [ArgumentError] for invalid input) so widgets can toast them.
class ShoppingController {
  final Ref _ref;

  const ShoppingController(this._ref);

  ShoppingRepository get _repository => _ref.read(shoppingRepositoryProvider);

  String get _householdId {
    final id = _ref.read(_activeHouseholdIdProvider);
    if (id == null) {
      throw StateError('Bạn chưa chọn gia đình hoạt động.');
    }
    return id;
  }

  String get _userId => _ref.read(currentUserProvider)?.id ?? '';

  Future<String> saveList({
    String? listId,
    required String name,
    String? note,
  }) {
    return SaveShoppingListUseCase(_repository)(
      householdId: _householdId,
      listId: listId,
      name: name,
      note: note,
      userId: _userId,
    );
  }

  Future<void> deleteList(String listId) {
    return DeleteShoppingListUseCase(_repository)(
      householdId: _householdId,
      listId: listId,
    );
  }

  Future<AddShoppingItemResult> addItem(
    String listId,
    ShoppingItemDraft draft,
  ) async {
    final result = await AddShoppingItemUseCase(_repository)(
      householdId: _householdId,
      listId: listId,
      draft: draft,
      userId: _userId,
    );
    _ref.invalidate(shoppingSuggestionsProvider);
    return result;
  }

  /// Adds [drafts] one by one. A failed item does not stop the others; its
  /// name is reported so the user can add it by hand.
  Future<AddShoppingItemsResult> addItems(
    String listId,
    List<ShoppingItemDraft> drafts,
  ) async {
    final useCase = AddShoppingItemUseCase(_repository);
    final householdId = _householdId;
    var added = 0;
    var merged = 0;
    final failedNames = <String>[];
    for (final draft in drafts) {
      try {
        final result = await useCase(
          householdId: householdId,
          listId: listId,
          draft: draft,
          userId: _userId,
        );
        result.merged ? merged++ : added++;
      } catch (_) {
        failedNames.add(draft.name);
      }
    }
    _ref.invalidate(shoppingSuggestionsProvider);
    return AddShoppingItemsResult(
      added: added,
      merged: merged,
      failedNames: failedNames,
    );
  }

  Future<void> updateItem(ShoppingItem item, ShoppingItemDraft draft) {
    return UpdateShoppingItemUseCase(_repository)(
      householdId: _householdId,
      listId: item.shoppingListId,
      itemId: item.id,
      draft: draft,
    );
  }

  Future<void> deleteItem(ShoppingItem item) {
    return DeleteShoppingItemUseCase(_repository)(
      householdId: _householdId,
      listId: item.shoppingListId,
      itemId: item.id,
    );
  }

  Future<void> setPurchased(ShoppingItem item, bool purchased) {
    return SetShoppingItemPurchasedUseCase(_repository)(
      householdId: _householdId,
      item: item,
      purchased: purchased,
      userId: _userId,
    );
  }

  Future<int> importToInventory(
    String listId,
    List<ImportShoppingItemRequest> items,
  ) async {
    final count = await ImportShoppingItemsToInventoryUseCase(_repository)(
      householdId: _householdId,
      listId: listId,
      items: items,
    );
    _ref.invalidate(shoppingSuggestionsProvider);
    return count;
  }
}

final shoppingControllerProvider = Provider<ShoppingController>(
  (ref) => ShoppingController(ref),
);

/// User-facing message for errors thrown by [ShoppingController].
String shoppingErrorMessage(Object error) {
  if (error is Failure) return error.message;
  if (error is ArgumentError) return '${error.message}';
  if (error is StateError) return error.message;
  return 'Đã xảy ra lỗi. Vui lòng thử lại.';
}

/// Food name autocomplete shared with the inventory form (master foods and
/// household history).
final shoppingFoodSuggestionsProvider = FutureProvider.autoDispose
    .family<List<FoodSuggestion>, String>((ref, query) {
      if (query.trim().isEmpty) return Future.value(const []);
      return ref
          .watch(inventoryRepositoryProvider)
          .searchFoodSuggestions(
            query: query,
            householdId: ref.watch(_activeHouseholdIdProvider),
          );
    });
