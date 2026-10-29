import '../entities/import_shopping_item_request.dart';
import '../repositories/shopping_repository.dart';

const int maxShoppingImportItems = 50;

class ImportShoppingItemsToInventoryUseCase {
  final ShoppingRepository _repository;

  const ImportShoppingItemsToInventoryUseCase(this._repository);

  Future<int> call({
    required String householdId,
    required String listId,
    required List<ImportShoppingItemRequest> items,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Vui lòng chọn ít nhất 1 món để nhập kho.');
    }
    if (items.length > maxShoppingImportItems) {
      throw ArgumentError('Chỉ nhập tối đa 50 món mỗi lần.');
    }
    if (items.any((i) => i.categoryId.isEmpty)) {
      throw ArgumentError('Vui lòng chọn danh mục cho mỗi món.');
    }
    if (items.any((i) => i.actualQuantity <= 0)) {
      throw ArgumentError('Số lượng thực mua phải lớn hơn 0.');
    }
    return _repository.importToInventory(
      householdId: householdId,
      listId: listId,
      items: items,
    );
  }
}
