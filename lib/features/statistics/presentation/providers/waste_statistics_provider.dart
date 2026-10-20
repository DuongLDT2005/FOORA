import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/statistics_remote_datasource.dart';
import '../../data/repositories/statistics_repository_impl.dart';
import '../../domain/entities/waste_statistics.dart';
import '../../domain/usecases/compute_waste_statistics.dart';
import '../../domain/usecases/get_status_change_records.dart';

/// Internal provider that assembles the repository from Firestore.
final _statisticsRepositoryProvider = Provider<StatisticsRepositoryImpl>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return StatisticsRepositoryImpl(
    dataSource: StatisticsRemoteDataSourceImpl(firestore: firestore),
  );
});

/// Fetches and computes [WasteStatistics] for the given number of months.
/// Uses [FutureProvider.family] so each period is cached independently, and
/// [autoDispose] so resources are freed when the page is left.
final wasteStatisticsProvider = FutureProvider.autoDispose
    .family<WasteStatistics, int>((ref, months) async {
      final user = ref.watch(currentUserProvider);
      final householdId = user?.activeHouseholdId;

      if (householdId == null || householdId.isEmpty) {
        // No household linked yet — return empty statistics.
        return WasteStatistics.empty;
      }

      final repository = ref.watch(_statisticsRepositoryProvider);
      final getRecords = GetStatusChangeRecords(repository);
      final compute = const ComputeWasteStatistics();

      final records = await getRecords(
        householdId: householdId,
        months: months,
      );

      return compute(
        records: records,
        nowUtc: DateTime.now().toUtc(),
        months: months,
      );
    });
