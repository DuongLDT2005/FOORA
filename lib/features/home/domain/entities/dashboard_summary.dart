import 'package:flutter/foundation.dart';

/// Pure domain entity representing dashboard summary cards on the mobile Home screen.
@immutable
class DashboardSummary {
  final int totalItems;
  final int freshItems;
  final int expiringSoonItems;
  final int expiredItems;

  const DashboardSummary({
    required this.totalItems,
    required this.freshItems,
    required this.expiringSoonItems,
    required this.expiredItems,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardSummary &&
        other.totalItems == totalItems &&
        other.freshItems == freshItems &&
        other.expiringSoonItems == expiringSoonItems &&
        other.expiredItems == expiredItems;
  }

  @override
  int get hashCode =>
      Object.hash(totalItems, freshItems, expiringSoonItems, expiredItems);
}
