import '../../../../core/constants/app_enums.dart';
import '../repositories/inventory_repository.dart';

class BatchUpdateInventoryStatusUseCase {
  final InventoryRepository repository;

  const BatchUpdateInventoryStatusUseCase(this.repository);

  Future<void> call(List<String> itemIds, InventoryItemStatus status, {required String householdId}) {
    if (itemIds.isEmpty) return Future.value();
    return repository.batchUpdateInventoryStatus(
      householdId: householdId,
      itemIds: itemIds,
      status: status,
    );
  }
}
