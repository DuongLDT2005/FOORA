import '../repositories/shopping_repository.dart';

class DeleteShoppingListUseCase {
  final ShoppingRepository _repository;

  const DeleteShoppingListUseCase(this._repository);

  Future<void> call({required String householdId, required String listId}) =>
      _repository.deleteShoppingList(householdId: householdId, listId: listId);
}
