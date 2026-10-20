import '../entities/status_change_record.dart';
import '../entities/waste_statistics.dart';
import '../../../../core/constants/app_enums.dart';

/// Pure-Dart use case that computes [WasteStatistics] from a flat list of
/// [StatusChangeRecord]s. Contains no Flutter or Firebase dependencies and
/// is therefore fully unit-testable in isolation.
class ComputeWasteStatistics {
  const ComputeWasteStatistics();

  static const Duration _vnOffset = Duration(hours: 7);
  static const int _maxTopFoods = 5;

  /// [nowUtc] — current time in UTC (injected for deterministic testing).
  /// [months] — 3, 6, or 12 calendar months to include (including current).
  /// Computes [WasteStatistics] from [records].
  /// Supports custom [startDate] and [endDate] range boundaries, or falls back to
  /// [months] (defaults to 6 if neither is specified).
  WasteStatistics call({
    required List<StatusChangeRecord> records,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nowUtc,
    int? months,
  }) {
    final nowVn = (nowUtc ?? DateTime.now().toUtc()).add(_vnOffset);

    // If months is specified, build monthly buckets; otherwise empty list.
    final hasMonths = months != null && months > 0;
    final buckets = hasMonths ? _buildBuckets(nowVn, months) : <_MonthKey>[];
    final bucketMap = <_MonthKey, _MutableBucket>{};
    for (final b in buckets) {
      bucketMap[b] = _MutableBucket();
    }

    int totalConsumed = 0;
    int totalDiscarded = 0;
    int discardedAfterExpiry = 0;

    // Group discarded items by foodId/normalizedName for the top-waste list.
    final groupCounts = <String, _FoodGroup>{};

    for (final record in records) {
      final changedUtc = record.statusChangedAt.toUtc();
      if (startDate != null && changedUtc.isBefore(startDate.toUtc())) {
        continue;
      }
      if (endDate != null && changedUtc.isAfter(endDate.toUtc())) {
        continue;
      }

      final changedVn = changedUtc.add(_vnOffset);
      final key = _MonthKey(changedVn.year, changedVn.month);
      final bucket = bucketMap[key];
      if (hasMonths && bucket == null) {
        continue; // outside the requested month buckets
      }

      if (record.status == InventoryItemStatus.consumed) {
        bucket?.consumed++;
        totalConsumed++;
      } else if (record.status == InventoryItemStatus.discarded) {
        bucket?.discarded++;
        totalDiscarded++;

        if (record.isDiscardedAfterExpiry) discardedAfterExpiry++;

        final group = groupCounts.putIfAbsent(
          record.groupKey,
          () => _FoodGroup(name: record.name, categoryId: record.categoryId),
        );
        group.count++;
        // Keep the most recent name for display.
        if (changedVn.isAfter(group.latestAt)) {
          group.latestAt = changedVn;
          group.name = record.name;
          group.categoryId = record.categoryId;
        }
      }
    }

    // Compute waste rate, rounded to 1 decimal place.
    final totalResolved = totalConsumed + totalDiscarded;
    double? wasteRatePercent;
    if (totalResolved > 0) {
      final raw = (totalDiscarded / totalResolved) * 100;
      wasteRatePercent = (raw * 10).round() / 10;
    }

    // Build ordered monthly list.
    final monthly = buckets
        .map(
          (k) => MonthlyWaste(
            year: k.year,
            month: k.month,
            consumed: bucketMap[k]!.consumed,
            discarded: bucketMap[k]!.discarded,
          ),
        )
        .toList();

    // Top-5 wasted foods, sorted by count desc then name asc.
    final sortedGroups = groupCounts.entries.toList()
      ..sort((a, b) {
        final diff = b.value.count - a.value.count;
        if (diff != 0) return diff;
        return a.value.name.compareTo(b.value.name);
      });

    final topWasted = sortedGroups
        .take(_maxTopFoods)
        .map(
          (e) => TopWastedFood(
            groupKey: e.key,
            name: e.value.name,
            categoryId: e.value.categoryId,
            count: e.value.count,
            percentOfDiscarded: totalDiscarded > 0
                ? (e.value.count / totalDiscarded) * 100
                : 0,
          ),
        )
        .toList();

    return WasteStatistics(
      monthly: monthly,
      totalConsumed: totalConsumed,
      totalDiscarded: totalDiscarded,
      discardedAfterExpiry: discardedAfterExpiry,
      topWasted: topWasted,
      wasteRatePercent: wasteRatePercent,
    );
  }

  /// Builds an ordered list of (year, month) keys from oldest to newest.
  List<_MonthKey> _buildBuckets(DateTime nowVn, int months) {
    final keys = <_MonthKey>[];
    for (int i = months - 1; i >= 0; i--) {
      // Subtract i months from the current month.
      int m = nowVn.month - i;
      int y = nowVn.year;
      while (m <= 0) {
        m += 12;
        y--;
      }
      keys.add(_MonthKey(y, m));
    }
    return keys;
  }
}

class _MonthKey {
  const _MonthKey(this.year, this.month);
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is _MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

class _MutableBucket {
  int consumed = 0;
  int discarded = 0;
}

class _FoodGroup {
  _FoodGroup({required this.name, required this.categoryId});
  String name;
  String categoryId;
  int count = 0;
  DateTime latestAt = DateTime.fromMillisecondsSinceEpoch(0);
}
