import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/inventory_remote_datasource.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/food_suggestion.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/storage_location.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/usecases/add_inventory_item.dart';
import '../../domain/usecases/batch_update_inventory_status_usecase.dart';

import '../../domain/usecases/get_inventory_items.dart';
import '../../domain/usecases/update_inventory_item.dart';
import 'inventory_form_state.dart';

// --- Data & Domain Providers ---

final inventoryRemoteDataSourceProvider = Provider<InventoryRemoteDataSource>((
  ref,
) {
  return InventoryRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(functionsProvider),
  );
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(
    remoteDataSource: ref.watch(inventoryRemoteDataSourceProvider),
  );
});

final addInventoryItemUseCaseProvider = Provider<AddInventoryItemUseCase>((
  ref,
) {
  return AddInventoryItemUseCase(ref.watch(inventoryRepositoryProvider));
});

final updateInventoryItemUseCaseProvider = Provider<UpdateInventoryItemUseCase>((
  ref,
) {
  return UpdateInventoryItemUseCase(ref.watch(inventoryRepositoryProvider));
});

final batchUpdateInventoryStatusUseCaseProvider = Provider<BatchUpdateInventoryStatusUseCase>((
  ref,
) {
  return BatchUpdateInventoryStatusUseCase(ref.watch(inventoryRepositoryProvider));
});

final getInventoryItemsUseCaseProvider = Provider<GetInventoryItemsUseCase>((
  ref,
) {
  return GetInventoryItemsUseCase(ref.watch(inventoryRepositoryProvider));
});

// --- Metadata Providers (Categories & Storage Locations from Firestore) ---

final foodCategoriesProvider = FutureProvider<List<FoodCategory>>((ref) async {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getCategories();
});

final storageLocationsProvider = FutureProvider<List<StorageLocation>>((
  ref,
) async {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getStorageLocations();
});

// --- Active Household Items Stream (For Smart Query & Inventory List) ---

final activeHouseholdInventoryStreamProvider =
    StreamProvider<List<InventoryItem>>((ref) {
      final user = ref.watch(currentUserProvider);
      final householdId = user?.activeHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        return Stream.value([]);
      }
      final getItemsUseCase = ref.watch(getInventoryItemsUseCaseProvider);
      return getItemsUseCase(householdId);
    });

// --- Inventory Form State Notifier ---

final inventoryFormNotifierProvider = StateNotifierProvider.autoDispose
    .family<InventoryFormNotifier, InventoryFormState, InventoryItem?>((
      ref,
      itemToEdit,
    ) {
      final repository = ref.watch(inventoryRepositoryProvider);
      final addUseCase = ref.watch(addInventoryItemUseCaseProvider);
      final updateUseCase = ref.watch(updateInventoryItemUseCaseProvider);
      final activeItems =
          ref.watch(activeHouseholdInventoryStreamProvider).valueOrNull ?? [];

      final categoriesAsync = ref.watch(foodCategoriesProvider);
      final locationsAsync = ref.watch(storageLocationsProvider);

      return InventoryFormNotifier(
        ref: ref,
        repository: repository,
        addUseCase: addUseCase,
        updateUseCase: updateUseCase,
        itemToEdit: itemToEdit,
        activeItems: activeItems,
        categories: categoriesAsync.valueOrNull ?? [],
        storageLocations: locationsAsync.valueOrNull ?? [],
      );
    });

class InventoryFormNotifier extends StateNotifier<InventoryFormState> {
  final Ref ref;
  final InventoryRepository repository;
  final AddInventoryItemUseCase addUseCase;
  final UpdateInventoryItemUseCase updateUseCase;
  final InventoryItem? itemToEdit;
  final List<InventoryItem> activeItems;

  InventoryFormNotifier({
    required this.ref,
    required this.repository,
    required this.addUseCase,
    required this.updateUseCase,
    this.itemToEdit,
    required this.activeItems,
    required List<FoodCategory> categories,
    required List<StorageLocation> storageLocations,
  }) : super(
         InventoryFormState.initial(
           itemToEdit: itemToEdit,
           categories: categories,
           storageLocations: storageLocations,
         ),
       ) {
    _initMetadata();
  }

  Future<void> _initMetadata() async {
    if (state.categories.isEmpty || state.storageLocations.isEmpty) {
      state = state.copyWith(isLoadingMetadata: true);
      try {
        final fetchedCategories = await repository.getCategories();
        final fetchedLocations = await repository.getStorageLocations();
        state = state.copyWith(
          categories: fetchedCategories,
          storageLocations: fetchedLocations,
          isLoadingMetadata: false,
        );
        if (itemToEdit == null) {
          if (fetchedCategories.isNotEmpty &&
              (state.categoryId.isEmpty || state.categoryId == 'vegetables')) {
            await onCategoryChanged(fetchedCategories.first.id);
          }
          if (fetchedLocations.isNotEmpty &&
              (state.storageLocationId.isEmpty ||
                  state.storageLocationId == 'fridge')) {
            await onLocationChanged(fetchedLocations.first.id);
          }
        } else {
          await _recalculateExpiry();
        }
      } catch (_) {
        state = state.copyWith(isLoadingMetadata: false);
      }
    } else {
      await _recalculateExpiry();
    }
  }

  Future<void> retryLoadMetadata() async {
    state = state.copyWith(categories: [], storageLocations: []);
    await _initMetadata();
  }

  Future<void> onNameChanged(String newName) async {
    state = state.copyWith(name: newName);
    _checkSmartInventoryMatch(newName);

    // Search food suggestions in master foods & household history
    final user = ref.read(currentUserProvider);
    final householdId = user?.activeHouseholdId;
    if (newName.trim().isNotEmpty) {
      final suggestions = await repository.searchFoodSuggestions(
        query: newName,
        householdId: householdId,
      );
      state = state.copyWith(
        suggestions: suggestions,
        showSuggestions: suggestions.isNotEmpty,
      );
    } else {
      state = state.copyWith(
        suggestions: [],
        showSuggestions: false,
      );
    }
  }

  void dismissSuggestions() {
    if (state.showSuggestions) {
      state = state.copyWith(showSuggestions: false);
    }
  }

  Future<void> onSelectSuggestion(FoodSuggestion suggestion) async {
    state = state.copyWith(
      name: suggestion.name,
      foodId: suggestion.foodId,
      categoryId: suggestion.categoryId.isNotEmpty ? suggestion.categoryId : state.categoryId,
      unit: suggestion.defaultUnit.isNotEmpty ? suggestion.defaultUnit : state.unit,
      photoUrl: suggestion.photoUrl,
      showSuggestions: false,
    );
    _checkSmartInventoryMatch(suggestion.name);
    await _recalculateExpiry();
  }

  void _checkSmartInventoryMatch(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty || itemToEdit != null) {
      state = state.copyWith(clearMatchedItem: true);
      return;
    }

    InventoryItem? match;
    for (final item in activeItems) {
      final itemName = item.name.toLowerCase().trim();
      if (itemName == clean ||
          itemName.contains(clean) ||
          clean.contains(itemName)) {
        match = item;
        break;
      }
    }

    if (match != null) {
      state = state.copyWith(matchedExistingItem: match);
    } else {
      state = state.copyWith(clearMatchedItem: true);
    }
  }

  Future<void> onCategoryChanged(String newCategoryId) async {
    state = state.copyWith(categoryId: newCategoryId);
    await _recalculateExpiry();
  }

  Future<void> onLocationChanged(String newLocationId) async {
    state = state.copyWith(storageLocationId: newLocationId);
    await _recalculateExpiry();
  }

  void onQuantityChanged(double newQty) {
    state = state.copyWith(quantity: newQty);
  }

  void onUnitChanged(String newUnit) {
    state = state.copyWith(unit: newUnit);
  }

  void onRemainingPercentageChanged(double newPercentage) {
    state = state.copyWith(remainingPercentage: newPercentage.toInt());
  }

  Future<void> onPurchaseDateChanged(DateTime newPurchaseDate) async {
    state = state.copyWith(purchaseDate: newPurchaseDate);
    await _recalculateExpiry();
  }

  void onExpirationDateChanged(DateTime newExpirationDate) {
    state = state.copyWith(expirationDate: newExpirationDate);
  }

  Future<void> _recalculateExpiry() async {
    try {
      final result = await repository.calculateExpiryWithRule(
        foodId: state.foodId,
        categoryId: state.categoryId,
        storageLocationId: state.storageLocationId,
        purchaseDate: state.purchaseDate,
      );
      state = state.copyWith(
        expirationDate: result.expirationDate,
        maxStorageTime: result.maxValue,
        minStorageTime: result.minValue,
        storageTimeUnit: result.unit,
        hasShelfLifeRule: result.hasRule,
      );
    } catch (_) {
      final fallbackDays = state.storageLocationId == 'freezer' ? 30 : 3;
      state = state.copyWith(
        expirationDate: state.purchaseDate.add(Duration(days: fallbackDays)),
        clearShelfLifeRule: true,
      );
    }
  }

  Future<bool> submit() async {
    // 1. Validate form fields first
    if (state.name.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Vui lòng nhập tên thực phẩm.');
      return false;
    }

    if (state.quantity <= 0) {
      state = state.copyWith(
        errorMessage: 'Số lượng thực phẩm phải lớn hơn 0.',
      );
      return false;
    }

    final purchaseDay = DateTime(
      state.purchaseDate.year,
      state.purchaseDate.month,
      state.purchaseDate.day,
    );
    final expiryDay = DateTime(
      state.expirationDate.year,
      state.expirationDate.month,
      state.expirationDate.day,
    );
    if (expiryDay.isBefore(purchaseDay)) {
      state = state.copyWith(
        errorMessage: 'Hạn sử dụng không thể trước ngày mua thực phẩm.',
      );
      return false;
    }

    // 2. Validate household context
    final user = ref.read(currentUserProvider);
    final householdId = user?.activeHouseholdId;

    if (householdId == null || householdId.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Chưa có thông tin tủ lạnh gia đình. Vui lòng đăng nhập lại.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final now = DateTime.now();
      if (itemToEdit != null) {
        final updated = itemToEdit!.copyWith(
          name: state.name.trim(),
          categoryId: state.categoryId,
          storageLocationId: state.storageLocationId,
          quantity: state.quantity,
          unit: state.unit,
          remainingPercentage: state.remainingPercentage,
          purchaseDate: state.purchaseDate,
          expirationDate: state.expirationDate,
          photoUrl: state.photoUrl,
          updatedAt: now,
        );
        await updateUseCase(updated, householdId: householdId);
      } else {
        final newItem = InventoryItem(
          id: '',
          foodId: state.foodId,
          name: state.name.trim(),
          normalizedName: state.name.trim().toLowerCase(),
          categoryId: state.categoryId,
          quantity: state.quantity,
          unit: state.unit,
          remainingPercentage: state.remainingPercentage,
          storageLocationId: state.storageLocationId,
          purchaseDate: state.purchaseDate,
          expirationDate: state.expirationDate,
          photoUrl: state.photoUrl,
          createdAt: now,
          updatedAt: now,
        );
        await addUseCase(newItem, householdId: householdId);
      }

      state = state.copyWith(isSubmitting: false);
      return true;
    } on Failure catch (f) {
      state = state.copyWith(isSubmitting: false, errorMessage: f.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Không thể lưu thực phẩm. Vui lòng thử lại sau.',
      );
      return false;
    }
  }
}
