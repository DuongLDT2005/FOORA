import '../entities/shopping_item.dart';
import '../repositories/shopping_repository.dart';

class SetShoppingItemPurchasedUseCase {
  final ShoppingRepository _repository;

  const SetShoppingItemPurchasedUseCase(this._repository);

  Future<void> call({
    required String householdId,
    required ShoppingItem item,
    required bool purchased,
    required String userId,
  }) {
    if (item.isLocked) {
      throw StateError('Món đã nhập vào tủ lạnh không thể đổi trạng thái.');
    }
    return _repository.setItemPurchased(
      householdId: householdId,
      listId: item.shoppingListId,
      itemId: item.id,
      purchased: purchased,
      userId: userId,
    );
  }
}
