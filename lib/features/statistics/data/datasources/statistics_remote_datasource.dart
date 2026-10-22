import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/status_change_record.dart';
import '../models/status_change_record_model.dart';

abstract class StatisticsRemoteDataSource {
  /// Returns consumed/discarded records whose `statusChangedAt` lies in
  /// `[from, to]`, newest first, capped at [limit].
  /// Throws [ServerException] on Firestore errors.
  Future<List<StatusChangeRecord>> getStatusChangeRecords({
    required String householdId,
    required DateTime from,
    DateTime? to,
    int limit,
  });
}

/// Queries Firestore for consumed/discarded inventory items within the period.
/// Uses a one-shot [get()] (not a stream) so that stats are only fetched on
/// demand and do not incur continuous listener costs.
///
/// Requires the composite index `inventory_items (status, statusChangedAt)`
/// declared in `firestore.indexes.json`.
class StatisticsRemoteDataSourceImpl implements StatisticsRemoteDataSource {
  const StatisticsRemoteDataSourceImpl({required this.firestore});

  final FirebaseFirestore firestore;

  @override
  Future<List<StatusChangeRecord>> getStatusChangeRecords({
    required String householdId,
    required DateTime from,
    DateTime? to,
    int limit = 2000,
  }) async {
    try {
      Query<Map<String, dynamic>> query = firestore
          .collection(FirestoreConstants.households)
          .doc(householdId)
          .collection(FirestoreConstants.inventoryItems)
          .where('status', whereIn: ['consumed', 'discarded'])
          .where(
            'statusChangedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from),
          );

      if (to != null) {
        query = query.where(
          'statusChangedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(to),
        );
      }

      // Newest first so that, when the limit is hit, the oldest records in
      // the period are the ones left out.
      final snapshot = await query
          .orderBy('statusChangedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map(StatusChangeRecordModel.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    }
  }
}
