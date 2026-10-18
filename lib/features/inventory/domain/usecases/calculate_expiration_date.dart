import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_enums.dart';
import '../entities/shelf_life_duration.dart';
import '../repositories/inventory_repository.dart';

/// Result of an expiration estimate: the date plus the rule it came from.
class ExpirationEstimate {
  final DateTime expirationDate;

  /// The matched recommendation, or `null` when a fallback was used.
  final ShelfLifeDuration? shelfLife;

  const ExpirationEstimate({required this.expirationDate, this.shelfLife});

  bool get hasRule => shelfLife?.isRecommended ?? false;
}

/// Estimates `expirationDate = purchaseDate + maxValue (unit)` as described in
/// docs/DATABASE.md §10. Without a recommendation (or if the lookup fails) it
/// falls back to [AppConstants.fallbackFridgeShelfLifeDays] /
/// [AppConstants.fallbackFreezerShelfLifeDays] so the user still gets a date
/// they can adjust.
class CalculateExpirationDateUseCase {
  final InventoryRepository repository;

  const CalculateExpirationDateUseCase(this.repository);

  Future<ExpirationEstimate> call({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
    required DateTime purchaseDate,
  }) async {
    ShelfLifeDuration? shelfLife;
    try {
      shelfLife = await repository.findShelfLife(
        foodId: foodId,
        categoryId: categoryId,
        storageLocationId: storageLocationId,
      );
    } catch (_) {
      shelfLife = null;
    }

    if (shelfLife == null || !shelfLife.isRecommended) {
      return ExpirationEstimate(
        expirationDate: purchaseDate.add(
          Duration(days: fallbackDays(storageLocationId)),
        ),
        shelfLife: shelfLife,
      );
    }

    final value = (shelfLife.maxValue ?? shelfLife.minValue)!.toInt();
    return ExpirationEstimate(
      expirationDate: addDuration(purchaseDate, value, shelfLife.unit!),
      shelfLife: shelfLife,
    );
  }

  /// Fallback duration in days when no recommendation exists.
  static int fallbackDays(String storageLocationId) {
    final isFreezer =
        storageLocationId.toUpperCase() == StorageLocationCode.freezer.value;
    return isFreezer
        ? AppConstants.fallbackFreezerShelfLifeDays
        : AppConstants.fallbackFridgeShelfLifeDays;
  }

  /// Adds [value] [unit]s to [from] using calendar months/years.
  static DateTime addDuration(DateTime from, int value, String unit) {
    switch (unit) {
      case 'weeks':
        return from.add(Duration(days: value * 7));
      case 'months':
        return DateTime(from.year, from.month + value, from.day);
      case 'years':
        return DateTime(from.year + value, from.month, from.day);
      case 'days':
      default:
        return from.add(Duration(days: value));
    }
  }
}
