import '../entities/dashboard_summary.dart';
import '../entities/home_dashboard_data.dart';

abstract class DashboardRepository {
  /// Stream the aggregated home dashboard data for a household
  Stream<HomeDashboardData> watchHomeDashboard(String householdId);

  /// Fetch instant dashboard summary metrics
  Future<DashboardSummary> getDashboardSummary(String householdId);
}
