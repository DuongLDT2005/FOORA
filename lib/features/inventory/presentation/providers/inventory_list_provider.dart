import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/inventory_item.dart';
import 'inventory_provider.dart';

enum InventorySortOption { newest, closestExpiry, nameAsc, quantityDesc }

enum InventoryStatusFilter { all, expiringSoon, expired, lowQuantity }

class InventoryListState {
  final String searchQuery;
  final String selectedLocationId; // 'all', 'fridge', 'freezer'
  final String selectedCategoryId; // 'all', or specific categoryId
  final InventorySortOption sortOption;
  final InventoryStatusFilter statusFilter;
  final List<InventoryItem> filteredItems;

  // Banner stats
  final int expiringSoonCount;
  final int expiredCount;

  const InventoryListState({
    required this.searchQuery,
    required this.selectedLocationId,
    required this.selectedCategoryId,
    required this.sortOption,
    required this.statusFilter,
    required this.filteredItems,
    required this.expiringSoonCount,
    required this.expiredCount,
  });

  factory InventoryListState.initial() {
    return const InventoryListState(
      searchQuery: '',
      selectedLocationId: 'all',
      selectedCategoryId: 'all',
      sortOption: InventorySortOption.newest,
      statusFilter: InventoryStatusFilter.all,
      filteredItems: [],
      expiringSoonCount: 0,
      expiredCount: 0,
    );
  }

  InventoryListState copyWith({
    String? searchQuery,
    String? selectedLocationId,
    String? selectedCategoryId,
    InventorySortOption? sortOption,
    InventoryStatusFilter? statusFilter,
    List<InventoryItem>? filteredItems,
    int? expiringSoonCount,
    int? expiredCount,
  }) {
    return InventoryListState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLocationId: selectedLocationId ?? this.selectedLocationId,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      sortOption: sortOption ?? this.sortOption,
      statusFilter: statusFilter ?? this.statusFilter,
      filteredItems: filteredItems ?? this.filteredItems,
      expiringSoonCount: expiringSoonCount ?? this.expiringSoonCount,
      expiredCount: expiredCount ?? this.expiredCount,
    );
  }
}

final inventoryListNotifierProvider =
    StateNotifierProvider<InventoryListNotifier, InventoryListState>((ref) {
      return InventoryListNotifier(ref);
    });

class InventoryListNotifier extends StateNotifier<InventoryListState> {
  final Ref ref;
  List<InventoryItem> _allItems = [];

  InventoryListNotifier(this.ref) : super(InventoryListState.initial()) {
    ref.listen<AsyncValue<List<InventoryItem>>>(
      activeHouseholdInventoryStreamProvider,
      (previous, next) {
        _allItems = next.valueOrNull ?? [];
        _applyFiltersAndSort();
      },
      fireImmediately: true,
    );
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFiltersAndSort();
  }

  void updateLocationFilter(String locationId) {
    state = state.copyWith(selectedLocationId: locationId);
    _applyFiltersAndSort();
  }

  void updateCategoryFilter(String categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
    _applyFiltersAndSort();
  }

  void updateSortOption(InventorySortOption option) {
    state = state.copyWith(sortOption: option);
    _applyFiltersAndSort();
  }

  void updateStatusFilter(InventoryStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
    _applyFiltersAndSort();
  }

  void resetFilters() {
    state = state.copyWith(
      sortOption: InventorySortOption.newest,
      statusFilter: InventoryStatusFilter.all,
    );
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    // 1. Calculate banner stats based on ALL active items (regardless of current filter)
    int expired = 0;
    int expiringSoon = 0;

    for (var item in _allItems) {
      if (item.status != InventoryItemStatus.active) continue;
      final expiryStatus = DateFormatter.getExpiryStatus(item.expirationDate);
      if (expiryStatus == ExpiryStatus.expired) {
        expired++;
      } else if (expiryStatus == ExpiryStatus.expiringSoon) {
        expiringSoon++;
      }
    }

    // 2. Filter
    final filtered = _allItems.where((item) {
      // Must be active to show in main list
      if (item.status != InventoryItemStatus.active) return false;

      // Location
      if (state.selectedLocationId != 'all' &&
          item.storageLocationId != state.selectedLocationId) {
        return false;
      }

      // Category
      if (state.selectedCategoryId != 'all' &&
          item.categoryId != state.selectedCategoryId) {
        return false;
      }

      // Search Query
      if (state.searchQuery.trim().isNotEmpty) {
        final query = state.searchQuery.trim().toLowerCase();
        if (!item.name.toLowerCase().contains(query) &&
            !item.normalizedName.contains(query)) {
          return false;
        }
      }

      // Status Filter
      if (state.statusFilter != InventoryStatusFilter.all) {
        final expiryStatus = DateFormatter.getExpiryStatus(item.expirationDate);
        if (state.statusFilter == InventoryStatusFilter.expired &&
            expiryStatus != ExpiryStatus.expired) {
          return false;
        }
        if (state.statusFilter == InventoryStatusFilter.expiringSoon &&
            expiryStatus != ExpiryStatus.expiringSoon) {
          return false;
        }
        if (state.statusFilter == InventoryStatusFilter.lowQuantity &&
            item.remainingPercentage > 25) {
          // Assuming <= 25% is low
          return false;
        }
      }

      return true;
    }).toList();

    // 3. Sort
    filtered.sort((a, b) {
      switch (state.sortOption) {
        case InventorySortOption.closestExpiry:
          return a.expirationDate.compareTo(b.expirationDate);
        case InventorySortOption.nameAsc:
          return a.name.compareTo(b.name);
        case InventorySortOption.quantityDesc:
          return a.remainingPercentage.compareTo(
            b.remainingPercentage,
          ); // ASC: lower remaining first
        case InventorySortOption.newest:
          return b.createdAt.compareTo(a.createdAt); // DESC: newest first
      }
    });

    state = state.copyWith(
      filteredItems: filtered,
      expiringSoonCount: expiringSoon,
      expiredCount: expired,
    );
  }
}
