import '../../../../core/utils/string_utils.dart';
import '../entities/shopping_item_draft.dart';
import '../repositories/shopping_repository.dart';
import 'validate_shopping_item_draft.dart';

class UpdateShoppingItemUseCase {
  final ShoppingRepository _repository;

  const UpdateShoppingItemUseCase(this._repository);

  Future<void> call({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingItemDraft draft,
  }) {
    final clean = validateShoppingItemDraft(draft);
    return _repository.updateShoppingItem(
      householdId: householdId,
      listId: listId,
      itemId: itemId,
      draft: clean,
      normalizedName: StringUtils.normalize(clean.name),
    );
  }
}
