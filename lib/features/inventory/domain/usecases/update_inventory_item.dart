import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class UpdateInventoryItemUseCase {
  final InventoryRepository repository;

  const UpdateInventoryItemUseCase(this.repository);

  Future<void> call(InventoryItem item, {required String householdId}) {
    return repository.updateInventoryItem(item, householdId: householdId);
  }
}
