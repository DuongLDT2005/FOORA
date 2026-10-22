import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/statistics_remote_datasource.dart';
import '../../data/repositories/statistics_repository_impl.dart';
import '../../domain/entities/stats_period.dart';
import '../../domain/entities/waste_statistics.dart';
import '../../domain/usecases/compute_waste_statistics.dart';
import '../../domain/usecases/get_status_change_records.dart';

/// Parameter object identifying a date range filter for [wasteStatisticsProvider].
/// Only the calendar days matter; times of day are ignored.
@immutable
class DateRangeParam {
  const DateRangeParam({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRangeParam &&
          runtimeType == other.runtimeType &&
          startDate.year == other.startDate.year &&
          startDate.month == other.startDate.month &&
          startDate.day == other.startDate.day &&
          endDate.year == other.endDate.year &&
          endDate.month == other.endDate.month &&
          endDate.day == other.endDate.day;

  @override
  int get hashCode => Object.hash(
    startDate.year,
    startDate.month,
    startDate.day,
    endDate.year,
    endDate.month,
    endDate.day,
  );
}

/// Internal provider that assembles the repository from Firestore.
final _statisticsRepositoryProvider = Provider<StatisticsRepositoryImpl>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return StatisticsRepositoryImpl(
    dataSource: StatisticsRemoteDataSourceImpl(firestore: firestore),
  );
});

/// Fetches and computes [WasteStatistics] for the given [DateRangeParam].
/// Uses [FutureProvider.family] so each range is cached independently, and
/// [autoDispose] so resources are freed when the page is left.
final wasteStatisticsProvider = FutureProvider.autoDispose
    .family<WasteStatistics, DateRangeParam>((ref, range) async {
      // Only rebuild when the active household changes, not on every
      // unrelated update of the user profile.
      final householdId = ref.watch(
        currentUserProvider.select((user) => user?.activeHouseholdId),
      );

      if (householdId == null || householdId.isEmpty) {
        // No household linked yet — return empty statistics.
        return WasteStatistics.empty;
      }

      final repository = ref.watch(_statisticsRepositoryProvider);
      final getRecords = GetStatusChangeRecords(repository);
      const compute = ComputeWasteStatistics();

      // Calendar days are interpreted in Vietnam time, regardless of the
      // device time zone.
      final period = StatsPeriod.fromCalendarDays(
        startDay: range.startDate,
        endDay: range.endDate,
      );

      final records = await getRecords(
        householdId: householdId,
        period: period,
      );

      return compute(
        records: records,
        startDate: period.startUtc,
        endDate: period.endUtc,
        recordLimit: GetStatusChangeRecords.maxRecords,
      );
    });
