import '../repositories/shopping_repository.dart';

class DeleteShoppingItemUseCase {
  final ShoppingRepository _repository;

  const DeleteShoppingItemUseCase(this._repository);

  Future<void> call({
    required String householdId,
    required String listId,
    required String itemId,
  }) => _repository.deleteShoppingItem(
    householdId: householdId,
    listId: listId,
    itemId: itemId,
  );
}
