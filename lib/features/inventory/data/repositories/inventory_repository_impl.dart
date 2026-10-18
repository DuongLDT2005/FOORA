import '../../../../core/constants/app_enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/food_suggestion.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/shelf_life_duration.dart';
import '../../domain/entities/storage_location.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_datasource.dart';
import '../models/inventory_item_model.dart';

/// Implementation of [InventoryRepository] on top of [InventoryRemoteDataSource].
/// Maps data-layer exceptions to domain [Failure]s and provides offline fallbacks.
class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDataSource remoteDataSource;

  const InventoryRepositoryImpl({required this.remoteDataSource});

  /// Adds a food item via the `addInventoryItem` Cloud Function.
  /// Throws [ResourceExhaustedFailure] when the plan's item limit is reached.
  @override
  Future<String> addInventoryItem(
    InventoryItem item, {
    required String householdId,
  }) async {
    try {
      return await remoteDataSource.addInventoryItem(
        householdId: householdId,
        name: item.name,
        foodId: item.foodId,
        categoryId: item.categoryId,
        quantity: item.quantity,
        unit: item.unit,
        storageLocationId: item.storageLocationId,
        purchaseDate: item.purchaseDate,
        expirationDate: item.expirationDate,
        photoUrl: item.photoUrl,
        source: item.source.value,
      );
    } on ServerException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw ResourceExhaustedFailure(e.message, e.code);
      }
      throw ServerFailure(e.message, e.code);
    } catch (_) {
      throw const ServerFailure(
        'Không thể thêm thực phẩm vào tủ lạnh. Vui lòng thử lại.',
      );
    }
  }

  /// Updates an existing inventory item.
  @override
  Future<void> updateInventoryItem(
    InventoryItem item, {
    required String householdId,
  }) async {
    try {
      final model = InventoryItemModel.fromEntity(item);
      await remoteDataSource.updateInventoryItem(
        householdId: householdId,
        item: model,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (_) {
      throw const ServerFailure(
        'Không thể cập nhật thực phẩm. Vui lòng thử lại.',
      );
    }
  }

  /// Changes the status (consumed / discarded ...) of many items at once.
  @override
  Future<void> batchUpdateInventoryStatus({
    required String householdId,
    required List<String> itemIds,
    required InventoryItemStatus status,
  }) async {
    try {
      await remoteDataSource.batchUpdateInventoryStatus(
        householdId: householdId,
        itemIds: itemIds,
        status: status.value,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (_) {
      throw const ServerFailure(
        'Không thể cập nhật hàng loạt. Vui lòng thử lại.',
      );
    }
  }

  /// Real-time stream of the household's active (not consumed/discarded) items.
  @override
  Stream<List<InventoryItem>> watchActiveInventoryItems(String householdId) {
    return remoteDataSource.watchActiveInventoryItems(householdId);
  }

  /// Loads all food categories.
  @override
  Future<List<FoodCategory>> getCategories() async {
    try {
      return await remoteDataSource.getCategories();
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (_) {
      throw const ServerFailure(
        'Không thể tải danh mục thực phẩm. Vui lòng thử lại.',
      );
    }
  }

  /// Loads all storage locations.
  @override
  Future<List<StorageLocation>> getStorageLocations() async {
    try {
      return await remoteDataSource.getStorageLocations();
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (_) {
      throw const ServerFailure(
        'Không thể tải vị trí bảo quản. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<ShelfLifeDuration?> findShelfLife({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
  }) async {
    try {
      return await remoteDataSource.findShelfLife(
        foodId: foodId,
        categoryId: categoryId,
        storageLocationId: storageLocationId,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (_) {
      throw const ServerFailure('Không thể tải thời hạn bảo quản.');
    }
  }

  /// Searches the food catalogue for autocomplete suggestions.
  @override
  Future<List<FoodSuggestion>> searchFoodSuggestions({
    required String query,
    String? householdId,
  }) async {
    return remoteDataSource.searchFoodSuggestions(
      query: query,
      householdId: householdId,
    );
  }
}
