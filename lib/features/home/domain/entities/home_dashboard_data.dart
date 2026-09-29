import 'package:flutter/foundation.dart';

import '../../../inventory/domain/entities/inventory_item.dart';

/// Pure domain entity representing dashboard state on the Home screen.
@immutable
class HomeDashboardData {
  final int totalCount;
  final int expiringSoonCount;
  final int expiredCount;
  final List<InventoryItem> useFirstItems;
  final List<InventoryItem> expiringSoonItems;
  final List<InventoryItem> recentItems;

  const HomeDashboardData({
    required this.totalCount,
    required this.expiringSoonCount,
    required this.expiredCount,
    required this.useFirstItems,
    required this.expiringSoonItems,
    required this.recentItems,
  });

  factory HomeDashboardData.empty() {
    return const HomeDashboardData(
      totalCount: 0,
      expiringSoonCount: 0,
      expiredCount: 0,
      useFirstItems: [],
      expiringSoonItems: [],
      recentItems: [],
    );
  }
}
