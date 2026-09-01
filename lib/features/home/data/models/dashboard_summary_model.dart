import 'package:foora/features/inventory/domain/entities/inventory_item.dart';

import '../../domain/entities/dashboard_summary.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.totalItems,
    required super.freshItems,
    required super.expiringSoonItems,
    required super.expiredItems,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      freshItems: (json['freshItems'] as num?)?.toInt() ?? 0,
      expiringSoonItems: (json['expiringSoonItems'] as num?)?.toInt() ?? 0,
      expiredItems: (json['expiredItems'] as num?)?.toInt() ?? 0,
    );
  }

  factory DashboardSummaryModel.fromInventoryItems(
    List<InventoryItem> items, {
    int warningThresholdDays = 3,
  }) {
    final now = DateTime.now();
    int expired = 0;
    int expiringSoon = 0;
    int fresh = 0;

    for (final item in items) {
      final days = item.expirationDate.difference(now).inDays;
      if (days < 0) {
        expired++;
      } else if (days <= warningThresholdDays) {
        expiringSoon++;
      } else {
        fresh++;
      }
    }

    return DashboardSummaryModel(
      totalItems: items.length,
      freshItems: fresh,
      expiringSoonItems: expiringSoon,
      expiredItems: expired,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalItems': totalItems,
      'freshItems': freshItems,
      'expiringSoonItems': expiringSoonItems,
      'expiredItems': expiredItems,
    };
  }
}
