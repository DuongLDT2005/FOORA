import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/string_utils.dart';
import '../../domain/entities/status_change_record.dart';

/// Firestore model for a consumed/discarded inventory-item document.
/// Includes safe fallbacks for legacy documents that lack [statusChangedAt].
class StatusChangeRecordModel extends StatusChangeRecord {
  const StatusChangeRecordModel({
    required super.id,
    super.foodId,
    required super.name,
    required super.normalizedName,
    required super.categoryId,
    required super.status,
    required super.statusChangedAt,
    required super.expirationDate,
    super.photoUrl,
  });

  factory StatusChangeRecordModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return StatusChangeRecordModel.fromJson(data, id: doc.id);
  }

  factory StatusChangeRecordModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
  }) {
    final name = json['name'] as String? ?? '';

    // Safe fallback: if statusChangedAt is missing (legacy doc pre-backfill),
    // use updatedAt then createdAt then now. This prevents crashes while the
    // backfill script is running and keeps statistics approximate.
    final statusChangedAt =
        _parseDt(json['statusChangedAt']) ??
        _parseDt(json['updatedAt']) ??
        _parseDt(json['createdAt']) ??
        DateTime.now();

    return StatusChangeRecordModel(
      id: id,
      foodId: json['foodId'] as String?,
      name: name,
      normalizedName:
          json['normalizedName'] as String? ?? StringUtils.normalize(name),
      categoryId: json['categoryId'] as String? ?? 'other',
      status: InventoryItemStatus.fromString(json['status'] as String?),
      statusChangedAt: statusChangedAt,
      expirationDate: _parseDt(json['expirationDate']) ?? DateTime.now(),
      photoUrl: json['photoUrl'] as String?,
    );
  }

  /// Accepts Timestamp, ISO-8601 string, or epoch millis; returns null if absent.
  static DateTime? _parseDt(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
