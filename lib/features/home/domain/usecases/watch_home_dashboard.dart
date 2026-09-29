import '../entities/home_dashboard_data.dart';
import '../repositories/dashboard_repository.dart';

class WatchHomeDashboardUseCase {
  final DashboardRepository repository;

  const WatchHomeDashboardUseCase(this.repository);

  Stream<HomeDashboardData> call(String householdId) {
    return repository.watchHomeDashboard(householdId);
  }
}
