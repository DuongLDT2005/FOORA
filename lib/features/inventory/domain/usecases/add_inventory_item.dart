import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class AddInventoryItemUseCase {
  final InventoryRepository repository;

  const AddInventoryItemUseCase(this.repository);

  Future<String> call(InventoryItem item, {required String householdId}) {
    return repository.addInventoryItem(item, householdId: householdId);
  }
}
