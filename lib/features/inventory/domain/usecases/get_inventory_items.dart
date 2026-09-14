import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class GetInventoryItemsUseCase {
  final InventoryRepository repository;

  const GetInventoryItemsUseCase(this.repository);

  Stream<List<InventoryItem>> call(String householdId) {
    return repository.watchActiveInventoryItems(householdId);
  }
}
