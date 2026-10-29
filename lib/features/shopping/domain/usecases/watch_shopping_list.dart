import '../entities/shopping_list.dart';
import '../repositories/shopping_repository.dart';

class WatchShoppingListUseCase {
  final ShoppingRepository _repository;

  const WatchShoppingListUseCase(this._repository);

  Stream<ShoppingList?> call(String householdId, String listId) =>
      _repository.watchShoppingList(householdId, listId);
}
