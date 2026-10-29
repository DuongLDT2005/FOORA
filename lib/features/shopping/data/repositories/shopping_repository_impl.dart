import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/import_shopping_item_request.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_item_draft.dart';
import '../../domain/entities/shopping_list.dart';
import '../../domain/entities/shopping_suggestion.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../datasources/shopping_remote_datasource.dart';

class ShoppingRepositoryImpl implements ShoppingRepository {
  final ShoppingRemoteDataSource remoteDataSource;

  const ShoppingRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<ShoppingList>> watchShoppingLists(String householdId) =>
      remoteDataSource.watchShoppingLists(householdId);

  @override
  Stream<ShoppingList?> watchShoppingList(String householdId, String listId) =>
      remoteDataSource.watchShoppingList(householdId, listId);

  @override
  Stream<List<ShoppingItem>> watchShoppingItems(
    String householdId,
    String listId,
  ) => remoteDataSource.watchShoppingItems(householdId, listId);

  @override
  Future<String> createShoppingList({
    required String householdId,
    required String name,
    String? note,
    required String createdBy,
  }) => _guard(
    () => remoteDataSource.createShoppingList(
      householdId: householdId,
      name: name,
      note: note,
      createdBy: createdBy,
    ),
  );

  @override
  Future<void> updateShoppingList({
    required String householdId,
    required String listId,
    required String name,
    String? note,
  }) => _guard(
    () => remoteDataSource.updateShoppingList(
      householdId: householdId,
      listId: listId,
      name: name,
      note: note,
    ),
  );

  @override
  Future<void> deleteShoppingList({
    required String householdId,
    required String listId,
  }) => _guard(
    () => remoteDataSource.deleteShoppingList(
      householdId: householdId,
      listId: listId,
    ),
  );

  @override
  Future<AddShoppingItemResult> addShoppingItem({
    required String householdId,
    required String listId,
    required ShoppingItemDraft draft,
    required String normalizedName,
    required String addedBy,
  }) => _guard(
    () => remoteDataSource.addShoppingItem(
      householdId: householdId,
      listId: listId,
      draft: draft,
      normalizedName: normalizedName,
      addedBy: addedBy,
    ),
  );

  @override
  Future<void> updateShoppingItem({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingItemDraft draft,
    required String normalizedName,
  }) => _guard(
    () => remoteDataSource.updateShoppingItem(
      householdId: householdId,
      listId: listId,
      itemId: itemId,
      draft: draft,
      normalizedName: normalizedName,
    ),
  );

  @override
  Future<void> deleteShoppingItem({
    required String householdId,
    required String listId,
    required String itemId,
  }) => _guard(
    () => remoteDataSource.deleteShoppingItem(
      householdId: householdId,
      listId: listId,
      itemId: itemId,
    ),
  );

  @override
  Future<void> setItemPurchased({
    required String householdId,
    required String listId,
    required String itemId,
    required bool purchased,
    required String userId,
  }) => _guard(
    () => remoteDataSource.setItemPurchased(
      householdId: householdId,
      listId: listId,
      itemId: itemId,
      purchased: purchased,
      userId: userId,
    ),
  );

  @override
  Future<int> importToInventory({
    required String householdId,
    required String listId,
    required List<ImportShoppingItemRequest> items,
  }) => _guard(
    () => remoteDataSource.importToInventory(
      householdId: householdId,
      listId: listId,
      items: items,
    ),
  );

  @override
  Future<List<ShoppingSuggestion>> getSuggestions(String householdId) =>
      _guard(() => remoteDataSource.getSuggestions(householdId));

  /// Converts data-layer exceptions to [Failure]s; the plan's food limit
  /// becomes [ResourceExhaustedFailure] so the UI can offer an upgrade.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ServerException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw ResourceExhaustedFailure(e.message, e.code);
      }
      throw Failure.fromException(e);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    }
  }
}
