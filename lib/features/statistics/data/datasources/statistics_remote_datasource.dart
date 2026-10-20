import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../domain/entities/status_change_record.dart';
import '../models/status_change_record_model.dart';

abstract class StatisticsRemoteDataSource {
  Future<List<StatusChangeRecord>> getStatusChangeRecords({
    required String householdId,
    required DateTime from,
    int limit,
  });
}

/// Queries Firestore for consumed/discarded inventory items within the period.
/// Uses a one-shot [get()] (not a stream) so that stats are only fetched on
/// demand and do not incur continuous listener costs.
class StatisticsRemoteDataSourceImpl implements StatisticsRemoteDataSource {
  const StatisticsRemoteDataSourceImpl({required this.firestore});

  final FirebaseFirestore firestore;

  @override
  Future<List<StatusChangeRecord>> getStatusChangeRecords({
    required String householdId,
    required DateTime from,
    int limit = 2000,
  }) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreConstants.households)
          .doc(householdId)
          .collection(FirestoreConstants.inventoryItems)
          .where('status', whereIn: ['consumed', 'discarded'])
          .where(
            'statusChangedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from),
          )
          .orderBy('statusChangedAt')
          .limit(limit)
          .get();

      return snapshot.docs.map(StatusChangeRecordModel.fromFirestore).toList();
    } on FirebaseException catch (e) {
      // Fallback: If composite index is missing or building on Firestore,
      // query by status (available out-of-the-box) and filter in-memory.
      if (e.code == 'failed-precondition') {
        final fallbackSnapshot = await firestore
            .collection(FirestoreConstants.households)
            .doc(householdId)
            .collection(FirestoreConstants.inventoryItems)
            .where('status', whereIn: ['consumed', 'discarded'])
            .limit(limit)
            .get();

        final records =
            fallbackSnapshot.docs
                .map(StatusChangeRecordModel.fromFirestore)
                .where((r) => !r.statusChangedAt.isBefore(from))
                .toList()
              ..sort((a, b) => a.statusChangedAt.compareTo(b.statusChangedAt));

        return records;
      }
      rethrow;
    }
  }
}
