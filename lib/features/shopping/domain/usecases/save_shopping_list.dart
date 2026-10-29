import '../repositories/shopping_repository.dart';

const int shoppingListNameMaxLength = 100;
const int shoppingNoteMaxLength = 200;

/// Creates a list, or renames it when [listId] is given.
class SaveShoppingListUseCase {
  final ShoppingRepository _repository;

  const SaveShoppingListUseCase(this._repository);

  Future<String> call({
    required String householdId,
    String? listId,
    required String name,
    String? note,
    required String userId,
  }) async {
    final trimmedName = name.trim();
    final trimmedNote = note?.trim();
    if (trimmedName.isEmpty || trimmedName.length > shoppingListNameMaxLength) {
      throw ArgumentError('Tên danh sách phải từ 1 đến 100 ký tự.');
    }
    if (trimmedNote != null && trimmedNote.length > shoppingNoteMaxLength) {
      throw ArgumentError('Ghi chú tối đa 200 ký tự.');
    }
    final cleanNote = trimmedNote == null || trimmedNote.isEmpty
        ? null
        : trimmedNote;
    if (listId == null) {
      return _repository.createShoppingList(
        householdId: householdId,
        name: trimmedName,
        note: cleanNote,
        createdBy: userId,
      );
    }
    await _repository.updateShoppingList(
      householdId: householdId,
      listId: listId,
      name: trimmedName,
      note: cleanNote,
    );
    return listId;
  }
}
