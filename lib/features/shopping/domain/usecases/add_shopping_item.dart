import '../../../../core/utils/string_utils.dart';
import '../entities/shopping_item_draft.dart';
import '../repositories/shopping_repository.dart';
import 'validate_shopping_item_draft.dart';

/// Adds an item; a pending item with the same name and unit is merged by
/// increasing its quantity (PLAN_01 §5.3).
class AddShoppingItemUseCase {
  final ShoppingRepository _repository;

  const AddShoppingItemUseCase(this._repository);

  Future<AddShoppingItemResult> call({
    required String householdId,
    required String listId,
    required ShoppingItemDraft draft,
    required String userId,
  }) {
    final clean = validateShoppingItemDraft(draft);
    return _repository.addShoppingItem(
      householdId: householdId,
      listId: listId,
      draft: clean,
      normalizedName: StringUtils.normalize(clean.name),
      addedBy: userId,
    );
  }
}
