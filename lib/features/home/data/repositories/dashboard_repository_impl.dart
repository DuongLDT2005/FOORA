import '../../../../core/utils/date_formatter.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/home_dashboard_data.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';
import '../models/dashboard_summary_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource remoteDataSource;

  const DashboardRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<HomeDashboardData> watchHomeDashboard(String householdId) {
    return remoteDataSource.watchActiveInventoryItems(householdId).map((items) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // 1. Calculate urgent & expired stats
      int expiredCount = 0;
      int urgentCount = 0;

      final List<InventoryItem> todayList = [];
      final List<InventoryItem> tomorrowList = [];
      final List<InventoryItem> upcomingList = [];

      for (final item in items) {
        final expiryStatus = DateFormatter.getExpiryStatus(item.expirationDate);
        final days = DateFormatter.getDaysUntilExpiry(item.expirationDate);

        if (expiryStatus == ExpiryStatus.expired) {
          expiredCount++;
        } else if (expiryStatus == ExpiryStatus.expiringSoon) {
          urgentCount++;
        }

        final itemExpDate = DateTime(
          item.expirationDate.year,
          item.expirationDate.month,
          item.expirationDate.day,
        );

        if (itemExpDate.isAtSameMomentAs(today)) {
          todayList.add(item);
        } else if (itemExpDate.isAtSameMomentAs(tomorrow)) {
          tomorrowList.add(item);
        } else if (days >= 2 && days <= 3) {
          upcomingList.add(item);
        }
      }

      // Sort by closest expiry date
      int compareByExpiry(InventoryItem a, InventoryItem b) =>
          a.expirationDate.compareTo(b.expirationDate);

      todayList.sort(compareByExpiry);
      tomorrowList.sort(compareByExpiry);
      upcomingList.sort(compareByExpiry);

      // 2. Use First (Horizontal Scroll) -> today + tomorrow + upcoming (max 10)
      final useFirstItems = [
        ...todayList,
        ...tomorrowList,
        ...upcomingList,
      ].take(10).toList();

      // 3. Expiring Soon (Vertical List) -> urgent items (max 5)
      final expiringSoonItems = [
        ...todayList,
        ...tomorrowList,
      ].take(5).toList();

      // 4. Recent Items (sort by createdAt DESC, max 4)
      final allItems = List<InventoryItem>.from(items)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final recentItems = allItems.take(4).toList();

      return HomeDashboardData(
        totalCount: items.length,
        expiringSoonCount: urgentCount,
        expiredCount: expiredCount,
        useFirstItems: useFirstItems,
        expiringSoonItems: expiringSoonItems,
        recentItems: recentItems,
      );
    });
  }

  @override
  Future<DashboardSummary> getDashboardSummary(String householdId) async {
    final items = await remoteDataSource
        .watchActiveInventoryItems(householdId)
        .first;
    return DashboardSummaryModel.fromInventoryItems(items);
  }
}
