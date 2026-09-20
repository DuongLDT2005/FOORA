import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/food_suggestion.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/storage_location.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_datasource.dart';
import '../models/inventory_item_model.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDataSource remoteDataSource;

  const InventoryRepositoryImpl({required this.remoteDataSource});

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
      throw const ServerFailure('Không thể thêm thực phẩm vào tủ lạnh. Vui lòng thử lại.');
    }
  }

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
      throw const ServerFailure('Không thể cập nhật thực phẩm. Vui lòng thử lại.');
    }
  }

  @override
  Stream<List<InventoryItem>> watchActiveInventoryItems(String householdId) {
    return remoteDataSource.watchActiveInventoryItems(householdId);
  }

  @override
  Future<List<FoodCategory>> getCategories() async {
    try {
      return await remoteDataSource.getCategories();
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (_) {
      throw const ServerFailure('Không thể tải danh mục thực phẩm. Vui lòng thử lại.');
    }
  }

  @override
  Future<List<StorageLocation>> getStorageLocations() async {
    try {
      return await remoteDataSource.getStorageLocations();
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (_) {
      throw const ServerFailure('Không thể tải vị trí bảo quản. Vui lòng thử lại.');
    }
  }

  @override
  Future<DateTime> calculateExpiryDate({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  }) async {
    try {
      return await remoteDataSource.calculateExpiryDate(
        foodId: foodId,
        categoryId: categoryId,
        storageLocationId: storageLocationId,
        purchaseDate: purchaseDate,
      );
    } catch (_) {
      final fallbackDays = storageLocationId == 'freezer' ? 30 : 3;
      return purchaseDate.add(Duration(days: fallbackDays));
    }
  }

  @override
  Future<({DateTime expirationDate, num? maxValue, num? minValue, String? unit, bool hasRule})>
  calculateExpiryWithRule({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  }) async {
    try {
      return await remoteDataSource.calculateExpiryWithRule(
        foodId: foodId,
        categoryId: categoryId,
        storageLocationId: storageLocationId,
        purchaseDate: purchaseDate,
      );
    } catch (_) {
      final fallbackDays = storageLocationId == 'freezer' ? 30 : 3;
      return (
        expirationDate: purchaseDate.add(Duration(days: fallbackDays)),
        maxValue: null,
        minValue: null,
        unit: null,
        hasRule: false,
      );
    }
  }

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
