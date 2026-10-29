import '../entities/shopping_list.dart';
import '../repositories/shopping_repository.dart';

class WatchShoppingListsUseCase {
  final ShoppingRepository _repository;

  const WatchShoppingListsUseCase(this._repository);

  Stream<List<ShoppingList>> call(String householdId) =>
      _repository.watchShoppingLists(householdId);
}
