import 'package:meta/meta.dart';

/// Aggregated consumed/discarded counts for a single calendar month.
@immutable
class MonthlyWaste {
  const MonthlyWaste({
    required this.year,
    required this.month,
    required this.consumed,
    required this.discarded,
  });

  final int year;
  final int month;
  final int consumed;
  final int discarded;

  /// Human-readable label, e.g. "05/26" for May 2026.
  String get label {
    final mm = month.toString().padLeft(2, '0');
    final yy = (year % 100).toString().padLeft(2, '0');
    return '$mm/$yy';
  }

  int get total => consumed + discarded;
}

/// One entry in the top-wasted foods list.
@immutable
class TopWastedFood {
  const TopWastedFood({
    required this.groupKey,
    required this.name,
    required this.categoryId,
    required this.count,
    required this.percentOfDiscarded,
  });

  /// Either a master foodId or a normalizedName (fallback).
  final String groupKey;
  final String name;
  final String categoryId;

  /// Number of discarded batches of this food in the selected period.
  final int count;

  /// Percentage of this food's discards relative to all discards in period.
  final double percentOfDiscarded;
}

/// Full waste-statistics result for a selected period.
@immutable
class WasteStatistics {
  const WasteStatistics({
    required this.monthly,
    required this.totalConsumed,
    required this.totalDiscarded,
    required this.discardedAfterExpiry,
    required this.topWasted,
    this.wasteRatePercent,
  });

  /// Sorted from oldest to newest; length == number of months requested.
  final List<MonthlyWaste> monthly;
  final int totalConsumed;
  final int totalDiscarded;

  /// Number of discarded batches where discardAt > expirationDate.
  final int discardedAfterExpiry;

  /// Top-5 foods by discard count, sorted descending then alphabetical.
  final List<TopWastedFood> topWasted;

  /// Null when no consumed+discarded items exist (denominator is zero).
  final double? wasteRatePercent;

  int get totalResolved => totalConsumed + totalDiscarded;
  bool get hasData => totalResolved > 0;

  static const WasteStatistics empty = WasteStatistics(
    monthly: [],
    totalConsumed: 0,
    totalDiscarded: 0,
    discardedAfterExpiry: 0,
    topWasted: [],
    wasteRatePercent: null,
  );
}
