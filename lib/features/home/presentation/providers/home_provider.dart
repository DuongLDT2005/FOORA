import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/datasources/dashboard_remote_datasource_impl.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/home_dashboard_data.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_summary.dart';
import '../../domain/usecases/watch_home_dashboard.dart';

// --- Data & Repository Providers ---

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((
  ref,
) {
  return DashboardRemoteDataSourceImpl(firestore: ref.watch(firestoreProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    remoteDataSource: ref.watch(dashboardRemoteDataSourceProvider),
  );
});

// --- UseCase Providers ---

final watchHomeDashboardUseCaseProvider = Provider<WatchHomeDashboardUseCase>((
  ref,
) {
  return WatchHomeDashboardUseCase(ref.watch(dashboardRepositoryProvider));
});

final getDashboardSummaryUseCaseProvider = Provider<GetDashboardSummaryUseCase>(
  (ref) {
    return GetDashboardSummaryUseCase(ref.watch(dashboardRepositoryProvider));
  },
);

// --- Home Presentation State Provider ---

final homeDashboardStreamProvider =
    StreamProvider.autoDispose<HomeDashboardData>((ref) {
      final user = ref.watch(currentUserProvider);
      final householdId = user?.activeHouseholdId;

      if (householdId == null || householdId.isEmpty) {
        return Stream.value(HomeDashboardData.empty());
      }

      final watchDashboard = ref.watch(watchHomeDashboardUseCaseProvider);
      return watchDashboard(householdId);
    });
