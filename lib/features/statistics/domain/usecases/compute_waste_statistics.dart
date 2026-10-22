import '../../../../core/constants/app_enums.dart';
import '../entities/status_change_record.dart';
import '../entities/waste_statistics.dart';

/// Pure-Dart use case that computes [WasteStatistics] from a flat list of
/// [StatusChangeRecord]s. Contains no Flutter or Firebase dependencies and
/// is therefore fully unit-testable in isolation.
class ComputeWasteStatistics {
  const ComputeWasteStatistics();

  static const Duration _vnOffset = Duration(hours: 7);
  static const int _maxTopFoods = 5;

  /// Computes [WasteStatistics] from [records].
  /// [startDate] / [endDate] — optional inclusive range boundaries.
  /// [nowUtc] — current time in UTC (injected for deterministic testing).
  /// [months] — when set, also builds that many monthly buckets (including
  /// the current month) and ignores records outside them.
  /// [recordLimit] — the fetch limit; reaching it marks the result truncated.
  WasteStatistics call({
    required List<StatusChangeRecord> records,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nowUtc,
    int? months,
    int? recordLimit,
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
        // Use the newest batch that actually has a photo, so a photo-less
        // latest batch does not hide an older batch's image.
        final photo = record.photoUrl;
        if (photo != null &&
            photo.isNotEmpty &&
            changedVn.isAfter(group.photoAt)) {
          group.photoAt = changedVn;
          group.photoUrl = photo;
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
            photoUrl: e.value.photoUrl,
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
      isTruncated: recordLimit != null && records.length >= recordLimit,
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
  String? photoUrl;
  DateTime photoAt = DateTime.fromMillisecondsSinceEpoch(0);
}
