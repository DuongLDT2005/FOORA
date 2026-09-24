import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardSummaryUseCase {
  final DashboardRepository repository;

  const GetDashboardSummaryUseCase(this.repository);

  Future<DashboardSummary> call(String householdId) {
    return repository.getDashboardSummary(householdId);
  }
}
