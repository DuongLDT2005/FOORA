import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/inventory_item.dart';
import 'inventory_provider.dart';

/// Sort options on the expiry management screen.
enum ExpirationSortType { expirationDate, quantity }

/// State of the expiry screen: items bucketed by how soon they expire.
class ExpirationListState {
  final List<InventoryItem> expiredItems;
  final List<InventoryItem> todayItems;
  final List<InventoryItem> tomorrowItems;
  final List<InventoryItem> upcomingItems; // 2-3 days
  final List<InventoryItem> safeItems; // > 3 days

  final int urgentCount;
  final int spoiledCount;
  final bool isLoading;
  final String? error;
  final ExpirationSortType sortType;

  const ExpirationListState({
    this.expiredItems = const [],
    this.todayItems = const [],
    this.tomorrowItems = const [],
    this.upcomingItems = const [],
    this.safeItems = const [],
    this.urgentCount = 0,
    this.spoiledCount = 0,
    this.isLoading = false,
    this.error,
    this.sortType = ExpirationSortType.expirationDate,
  });

  /// Returns a copy with the given fields replaced.
  ExpirationListState copyWith({
    List<InventoryItem>? expiredItems,
    List<InventoryItem>? todayItems,
    List<InventoryItem>? tomorrowItems,
    List<InventoryItem>? upcomingItems,
    List<InventoryItem>? safeItems,
    int? urgentCount,
    int? spoiledCount,
    bool? isLoading,
    String? error,
    ExpirationSortType? sortType,
  }) {
    return ExpirationListState(
      expiredItems: expiredItems ?? this.expiredItems,
      todayItems: todayItems ?? this.todayItems,
      tomorrowItems: tomorrowItems ?? this.tomorrowItems,
      upcomingItems: upcomingItems ?? this.upcomingItems,
      safeItems: safeItems ?? this.safeItems,
      urgentCount: urgentCount ?? this.urgentCount,
      spoiledCount: spoiledCount ?? this.spoiledCount,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      sortType: sortType ?? this.sortType,
    );
  }
}

/// Buckets active inventory items by expiry date and keeps them sorted.
class ExpirationListNotifier extends StateNotifier<ExpirationListState> {
  ExpirationListNotifier() : super(const ExpirationListState());

  /// Re-groups [activeItems] into expired / today / tomorrow / upcoming / safe
  /// and recomputes the urgent & spoiled counters.
  void updateItems(List<InventoryItem> activeItems) {
    if (activeItems.isEmpty) {
      state = const ExpirationListState();
      return;
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));
    final startOfDayAfterTomorrow = startOfToday.add(const Duration(days: 2));
    final startOfFourDaysFromNow = startOfToday.add(const Duration(days: 4));

    final expired = <InventoryItem>[];
    final today = <InventoryItem>[];
    final tomorrow = <InventoryItem>[];
    final upcoming = <InventoryItem>[];
    final safe = <InventoryItem>[];

    for (final item in activeItems) {
      final expiry = item.expirationDate;
      final startOfExpiry = DateTime(expiry.year, expiry.month, expiry.day);

      if (startOfExpiry.isBefore(startOfToday)) {
        expired.add(item);
      } else if (startOfExpiry.isAtSameMomentAs(startOfToday)) {
        today.add(item);
      } else if (startOfExpiry.isAtSameMomentAs(startOfTomorrow)) {
        tomorrow.add(item);
      } else if (startOfExpiry.isAtSameMomentAs(startOfDayAfterTomorrow) ||
          (startOfExpiry.isAfter(startOfDayAfterTomorrow) &&
              startOfExpiry.isBefore(startOfFourDaysFromNow))) {
        upcoming.add(item);
      } else {
        safe.add(item);
      }
    }

    // Sort each list based on current sortType
    int compareItems(InventoryItem a, InventoryItem b) {
      if (state.sortType == ExpirationSortType.expirationDate) {
        final dateCmp = a.expirationDate.compareTo(b.expirationDate);
        if (dateCmp != 0) return dateCmp;
        return a.name.compareTo(b.name);
      } else {
        final qtyCmp = a.quantity.compareTo(b.quantity);
        if (qtyCmp != 0) return qtyCmp;
        return a.expirationDate.compareTo(b.expirationDate);
      }
    }

    expired.sort(compareItems);
    today.sort(compareItems);
    tomorrow.sort(compareItems);
    upcoming.sort(compareItems);
    safe.sort(compareItems);

    final urgentCount = today.length + tomorrow.length + upcoming.length;
    final spoiledCount = expired.length;

    state = state.copyWith(
      expiredItems: expired,
      todayItems: today,
      tomorrowItems: tomorrow,
      upcomingItems: upcoming,
      safeItems: safe,
      urgentCount: urgentCount,
      spoiledCount: spoiledCount,
      isLoading: false,
    );
  }

  /// Toggles the loading flag.
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// Shows loading only when there is no data yet (avoids flicker on refresh).
  void handleStreamLoading() {
    if (!state.isLoading &&
        state.expiredItems.isEmpty &&
        state.safeItems.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
  }

  /// Stores an error message.
  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  /// Changes the sort order and re-sorts every bucket.
  void setSortType(ExpirationSortType type) {
    if (state.sortType == type) return;

    int compareItems(InventoryItem a, InventoryItem b) {
      if (type == ExpirationSortType.expirationDate) {
        final dateCmp = a.expirationDate.compareTo(b.expirationDate);
        if (dateCmp != 0) return dateCmp;
        return a.name.compareTo(b.name);
      } else {
        final qtyCmp = a.quantity.compareTo(b.quantity);
        if (qtyCmp != 0) return qtyCmp;
        return a.expirationDate.compareTo(b.expirationDate);
      }
    }

    final expired = List<InventoryItem>.from(state.expiredItems)
      ..sort(compareItems);
    final today = List<InventoryItem>.from(state.todayItems)
      ..sort(compareItems);
    final tomorrow = List<InventoryItem>.from(state.tomorrowItems)
      ..sort(compareItems);
    final upcoming = List<InventoryItem>.from(state.upcomingItems)
      ..sort(compareItems);
    final safe = List<InventoryItem>.from(state.safeItems)..sort(compareItems);

    state = state.copyWith(
      sortType: type,
      expiredItems: expired,
      todayItems: today,
      tomorrowItems: tomorrow,
      upcomingItems: upcoming,
      safeItems: safe,
    );
  }
}

/// Provides [ExpirationListNotifier], fed by the active-inventory stream.
final expirationListNotifierProvider =
    StateNotifierProvider.autoDispose<
      ExpirationListNotifier,
      ExpirationListState
    >((ref) {
      final notifier = ExpirationListNotifier();

      notifier.setLoading(true);

      // Listen to the active inventory stream
      ref.listen<AsyncValue<List<InventoryItem>>>(
        activeHouseholdInventoryStreamProvider,
        (previous, next) {
          next.when(
            data: (items) {
              notifier.updateItems(items);
            },
            loading: () {
              notifier.handleStreamLoading();
            },
            error: (error, stack) {
              notifier.setError(error.toString());
            },
          );
        },
        fireImmediately: true,
      );

      return notifier;
    });
