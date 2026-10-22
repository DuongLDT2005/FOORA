import 'package:meta/meta.dart';

import '../../../../core/constants/app_enums.dart';

/// A lightweight record used solely for waste statistics computation.
/// Only carries the fields needed for bucketing and grouping — no UI state.
@immutable
class StatusChangeRecord {
  const StatusChangeRecord({
    required this.id,
    this.foodId,
    required this.name,
    required this.normalizedName,
    required this.categoryId,
    required this.status,
    required this.statusChangedAt,
    required this.expirationDate,
    this.photoUrl,
  });

  final String id;

  /// Non-null when the item was matched to a master food document.
  final String? foodId;

  final String name;
  final String normalizedName;
  final String categoryId;
  final InventoryItemStatus status;

  /// The exact server timestamp at which the item became consumed/discarded.
  final DateTime statusChangedAt;

  /// Used to determine whether the item was discarded after expiry.
  final DateTime expirationDate;

  /// Item photo copied from the master food or uploaded by the user, if any.
  final String? photoUrl;

  /// True when a discarded item was thrown away after its expiration date.
  bool get isDiscardedAfterExpiry =>
      status == InventoryItemStatus.discarded &&
      statusChangedAt.isAfter(expirationDate);

  /// Key used to group items by food type when computing the top-wasted list.
  /// Prefers [foodId] (stable master-data ID) over [normalizedName].
  String get groupKey =>
      (foodId != null && foodId!.isNotEmpty) ? foodId! : normalizedName;
}
