import '../entities/shopping_item.dart';
import '../repositories/shopping_repository.dart';

class WatchShoppingItemsUseCase {
  final ShoppingRepository _repository;

  const WatchShoppingItemsUseCase(this._repository);

  Stream<List<ShoppingItem>> call(String householdId, String listId) =>
      _repository.watchShoppingItems(householdId, listId);
}
