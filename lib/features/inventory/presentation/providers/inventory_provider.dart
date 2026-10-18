import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/string_utils.dart';
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
import '../../domain/usecases/calculate_expiration_date.dart';

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

final updateInventoryItemUseCaseProvider = Provider<UpdateInventoryItemUseCase>(
  (ref) {
    return UpdateInventoryItemUseCase(ref.watch(inventoryRepositoryProvider));
  },
);

final batchUpdateInventoryStatusUseCaseProvider =
    Provider<BatchUpdateInventoryStatusUseCase>((ref) {
      return BatchUpdateInventoryStatusUseCase(
        ref.watch(inventoryRepositoryProvider),
      );
    });

/// Moves items of the active household to `consumed` / `discarded`.
final inventoryStatusControllerProvider = Provider<InventoryStatusController>(
  InventoryStatusController.new,
);

/// Coordinates status changes between the UI and the domain use case.
/// Throws a [Failure] with a user-facing message on error.
class InventoryStatusController {
  final Ref ref;

  InventoryStatusController(this.ref);

  Future<void> changeStatus(
    List<String> itemIds,
    InventoryItemStatus status,
  ) async {
    final householdId = ref.read(currentUserProvider)?.activeHouseholdId;
    if (householdId == null || householdId.isEmpty) {
      throw const NotFoundFailure('Chưa có thông tin tủ lạnh gia đình.');
    }
    try {
      await ref.read(batchUpdateInventoryStatusUseCaseProvider)(
        itemIds,
        status,
        householdId: householdId,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const ServerFailure(
        'Không thể cập nhật thực phẩm. Vui lòng thử lại.',
      );
    }
  }
}

final calculateExpirationDateUseCaseProvider =
    Provider<CalculateExpirationDateUseCase>((ref) {
      return CalculateExpirationDateUseCase(
        ref.watch(inventoryRepositoryProvider),
      );
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

/// Drives the add/edit item form: loads metadata, autocompletes names,
/// recalculates the expiry date and submits the item.
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

  /// Loads categories and storage locations for the dropdowns.
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

  /// Retries loading metadata after a failure.
  Future<void> retryLoadMetadata() async {
    state = state.copyWith(categories: [], storageLocations: []);
    await _initMetadata();
  }

  Timer? _searchDebounce;

  /// Bumped on every keystroke and selection, so a slow search that finishes
  /// late cannot overwrite newer results or reopen the dropdown.
  int _searchSeq = 0;

  /// Name of the suggestion picked in this form. Editing the name away from
  /// it unlinks that food, so its photo and shelf-life rule are not kept.
  String? _selectedSuggestionName;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Updates the name, searches suggestions and checks for duplicates.
  Future<void> onNameChanged(String newName) async {
    final unlinkSelection =
        _selectedSuggestionName != null &&
        newName.trim() != _selectedSuggestionName;
    state = state.copyWith(
      name: newName,
      clearFoodId: unlinkSelection,
      clearPhotoUrl: unlinkSelection,
    );
    if (unlinkSelection) {
      _selectedSuggestionName = null;
      unawaited(_recalculateExpiry());
    }
    _checkSmartInventoryMatch(newName);

    _searchDebounce?.cancel();
    final seq = ++_searchSeq;
    if (newName.trim().isEmpty) {
      state = state.copyWith(suggestions: [], showSuggestions: false);
      return;
    }

    // Search food suggestions in master foods & household history
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      final householdId = ref.read(currentUserProvider)?.activeHouseholdId;
      final suggestions = await repository.searchFoodSuggestions(
        query: newName,
        householdId: householdId,
      );
      if (!mounted || seq != _searchSeq) return;
      state = state.copyWith(
        suggestions: suggestions,
        showSuggestions: suggestions.isNotEmpty,
      );
    });
  }

  /// Hides the autocomplete dropdown.
  void dismissSuggestions() {
    if (state.showSuggestions) {
      state = state.copyWith(showSuggestions: false);
    }
  }

  /// Fills name/category/location from a suggestion and recalculates expiry.
  Future<void> onSelectSuggestion(FoodSuggestion suggestion) async {
    _searchDebounce?.cancel();
    _searchSeq++;
    _selectedSuggestionName = suggestion.name.trim();
    state = state.copyWith(
      name: suggestion.name,
      foodId: suggestion.foodId,
      categoryId: suggestion.categoryId.isNotEmpty
          ? suggestion.categoryId
          : state.categoryId,
      unit: suggestion.defaultUnit.isNotEmpty
          ? suggestion.defaultUnit
          : state.unit,
      photoUrl: suggestion.photoUrl,
      showSuggestions: false,
    );
    _checkSmartInventoryMatch(suggestion.name);
    await _recalculateExpiry();
  }

  /// "Smart inventory": warns if a similar item is already in the household,
  /// helping users avoid buying duplicates.
  void _checkSmartInventoryMatch(String query) {
    final clean = StringUtils.normalize(query);
    if (clean.isEmpty || itemToEdit != null) {
      state = state.copyWith(clearMatchedItem: true);
      return;
    }

    InventoryItem? match;
    for (final item in activeItems) {
      // Same food when the names are equal or one extends the other by whole
      // words ("Trứng" / "Trứng gà"), so a single letter does not match.
      final itemName = StringUtils.normalize(item.name);
      if (itemName.isNotEmpty &&
          (itemName == clean ||
              itemName.startsWith('$clean ') ||
              clean.startsWith('$itemName '))) {
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

  /// Category changed -> expiry must be recalculated.
  Future<void> onCategoryChanged(String newCategoryId) async {
    state = state.copyWith(categoryId: newCategoryId);
    await _recalculateExpiry();
  }

  /// Storage location changed -> expiry must be recalculated.
  Future<void> onLocationChanged(String newLocationId) async {
    state = state.copyWith(storageLocationId: newLocationId);
    await _recalculateExpiry();
  }

  // Simple field setters.
  void onQuantityChanged(double newQty) {
    state = state.copyWith(quantity: newQty);
  }

  void onUnitChanged(String newUnit) {
    state = state.copyWith(unit: newUnit);
  }

  void onRemainingPercentageChanged(double newPercentage) {
    state = state.copyWith(remainingPercentage: newPercentage.toInt());
  }

  /// Purchase date changed -> expiry must be recalculated.
  Future<void> onPurchaseDateChanged(DateTime newPurchaseDate) async {
    state = state.copyWith(purchaseDate: newPurchaseDate);
    await _recalculateExpiry();
  }

  void onExpirationDateChanged(DateTime newExpirationDate) {
    state = state.copyWith(expirationDate: newExpirationDate);
  }

  /// Recalculates the expiry date + rule hint for the current fields.
  Future<void> _recalculateExpiry() async {
    final estimate = await ref.read(calculateExpirationDateUseCaseProvider)(
      foodId: state.foodId,
      categoryId: state.categoryId,
      storageLocationId: state.storageLocationId,
      purchaseDate: state.purchaseDate,
    );
    if (!mounted) return;
    final shelfLife = estimate.shelfLife;
    state = shelfLife == null
        ? state.copyWith(
            expirationDate: estimate.expirationDate,
            clearShelfLifeRule: true,
          )
        : state.copyWith(
            expirationDate: estimate.expirationDate,
            maxStorageTime: shelfLife.maxValue,
            minStorageTime: shelfLife.minValue,
            storageTimeUnit: shelfLife.unit,
            hasShelfLifeRule: estimate.hasRule,
          );
  }

  /// Validates and saves the item (update if editing, add otherwise).
  /// Returns `true` on success.
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
