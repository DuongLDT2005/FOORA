import '../../../inventory/data/models/inventory_item_model.dart';

abstract class DashboardRemoteDataSource {
  /// Stream active inventory items of a household to calculate dashboard views
  Stream<List<InventoryItemModel>> watchActiveInventoryItems(
    String householdId,
  );
}
