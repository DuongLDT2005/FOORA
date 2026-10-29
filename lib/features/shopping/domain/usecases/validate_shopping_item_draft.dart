import '../entities/shopping_item_draft.dart';

const int shoppingItemNameMaxLength = 100;
const int shoppingItemUnitMaxLength = 20;
const int shoppingItemNoteMaxLength = 200;
const double shoppingItemMaxQuantity = 10000;

/// Trims [draft] and checks the limits also enforced by Firestore Rules.
/// Throws [ArgumentError] with a Vietnamese message when invalid.
ShoppingItemDraft validateShoppingItemDraft(ShoppingItemDraft draft) {
  final name = draft.name.trim();
  final unit = draft.unit.trim();
  final note = draft.note?.trim();
  if (name.isEmpty || name.length > shoppingItemNameMaxLength) {
    throw ArgumentError('Tên món phải từ 1 đến 100 ký tự.');
  }
  if (!draft.quantity.isFinite ||
      draft.quantity <= 0 ||
      draft.quantity > shoppingItemMaxQuantity) {
    throw ArgumentError('Số lượng phải lớn hơn 0 và không quá 10000.');
  }
  if (unit.isEmpty || unit.length > shoppingItemUnitMaxLength) {
    throw ArgumentError('Vui lòng chọn đơn vị.');
  }
  if (note != null && note.length > shoppingItemNoteMaxLength) {
    throw ArgumentError('Ghi chú tối đa 200 ký tự.');
  }
  return ShoppingItemDraft(
    name: name,
    quantity: draft.quantity,
    unit: unit,
    note: note == null || note.isEmpty ? null : note,
    foodId: draft.foodId,
    categoryId: draft.categoryId,
    source: draft.source,
  );
}
