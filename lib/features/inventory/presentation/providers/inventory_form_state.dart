import '../../domain/entities/food_category.dart';
import '../../domain/entities/food_suggestion.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/storage_location.dart';

class InventoryFormState {
  final String name;
  final String? foodId;
  final String categoryId;
  final String storageLocationId;
  final double quantity;
  final String unit;
  final int remainingPercentage;
  final DateTime purchaseDate;
  final DateTime expirationDate;
  final bool isSubmitting;
  final String? errorMessage;
  final InventoryItem? matchedExistingItem;
  final List<FoodCategory> categories;
  final List<StorageLocation> storageLocations;
  final bool isLoadingMetadata;

  // New: Shelf life rule parameter tracking for UI alert
  final num? maxStorageTime;
  final num? minStorageTime;
  final String? storageTimeUnit; // 'days', 'weeks', 'months', 'years'
  final bool hasShelfLifeRule;

  // New: Autocomplete suggestions
  final List<FoodSuggestion> suggestions;
  final bool showSuggestions;

  const InventoryFormState({
    required this.name,
    this.foodId,
    required this.categoryId,
    required this.storageLocationId,
    required this.quantity,
    required this.unit,
    required this.remainingPercentage,
    required this.purchaseDate,
    required this.expirationDate,
    this.isSubmitting = false,
    this.errorMessage,
    this.matchedExistingItem,
    this.categories = const [],
    this.storageLocations = const [],
    this.isLoadingMetadata = false,
    this.maxStorageTime,
    this.minStorageTime,
    this.storageTimeUnit,
    this.hasShelfLifeRule = false,
    this.suggestions = const [],
    this.showSuggestions = false,
  });

  factory InventoryFormState.initial({
    InventoryItem? itemToEdit,
    List<FoodCategory> categories = const [],
    List<StorageLocation> storageLocations = const [],
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (itemToEdit != null) {
      return InventoryFormState(
        name: itemToEdit.name,
        foodId: itemToEdit.foodId,
        categoryId: itemToEdit.categoryId,
        storageLocationId: itemToEdit.storageLocationId,
        quantity: itemToEdit.quantity,
        unit: itemToEdit.unit,
        remainingPercentage: itemToEdit.remainingPercentage,
        purchaseDate: itemToEdit.purchaseDate,
        expirationDate: itemToEdit.expirationDate,
        categories: categories,
        storageLocations: storageLocations,
        suggestions: const [],
        showSuggestions: false,
        hasShelfLifeRule: false,
      );
    }

    final initialCategory = categories.isNotEmpty
        ? categories.first.id
        : 'vegetables';
    final initialLocation = storageLocations.isNotEmpty
        ? storageLocations.first.id
        : 'fridge';

    return InventoryFormState(
      name: '',
      categoryId: initialCategory,
      storageLocationId: initialLocation,
      quantity: 1,
      unit: 'quả',
      remainingPercentage: 100,
      purchaseDate: today,
      expirationDate: today.add(const Duration(days: 5)),
      categories: categories,
      storageLocations: storageLocations,
      suggestions: const [],
      showSuggestions: false,
      hasShelfLifeRule: false,
    );
  }

  InventoryFormState copyWith({
    String? name,
    String? foodId,
    bool clearFoodId = false,
    String? categoryId,
    String? storageLocationId,
    double? quantity,
    String? unit,
    int? remainingPercentage,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    bool? isSubmitting,
    String? errorMessage,
    InventoryItem? matchedExistingItem,
    bool clearMatchedItem = false,
    List<FoodCategory>? categories,
    List<StorageLocation>? storageLocations,
    bool? isLoadingMetadata,
    num? maxStorageTime,
    num? minStorageTime,
    String? storageTimeUnit,
    bool? hasShelfLifeRule,
    bool clearShelfLifeRule = false,
    List<FoodSuggestion>? suggestions,
    bool? showSuggestions,
  }) {
    return InventoryFormState(
      name: name ?? this.name,
      foodId: clearFoodId ? null : (foodId ?? this.foodId),
      categoryId: categoryId ?? this.categoryId,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      remainingPercentage: remainingPercentage ?? this.remainingPercentage,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expirationDate: expirationDate ?? this.expirationDate,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      matchedExistingItem: clearMatchedItem
          ? null
          : (matchedExistingItem ?? this.matchedExistingItem),
      categories: categories ?? this.categories,
      storageLocations: storageLocations ?? this.storageLocations,
      isLoadingMetadata: isLoadingMetadata ?? this.isLoadingMetadata,
      maxStorageTime: clearShelfLifeRule ? null : (maxStorageTime ?? this.maxStorageTime),
      minStorageTime: clearShelfLifeRule ? null : (minStorageTime ?? this.minStorageTime),
      storageTimeUnit: clearShelfLifeRule ? null : (storageTimeUnit ?? this.storageTimeUnit),
      hasShelfLifeRule: clearShelfLifeRule ? false : (hasShelfLifeRule ?? this.hasShelfLifeRule),
      suggestions: suggestions ?? this.suggestions,
      showSuggestions: showSuggestions ?? this.showSuggestions,
    );
  }
}
