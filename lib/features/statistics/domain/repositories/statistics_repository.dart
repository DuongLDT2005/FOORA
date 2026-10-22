import '../entities/status_change_record.dart';

/// Domain repository interface for fetching raw inventory status-change records
/// from the data source. The implementation lives in the data layer.
abstract class StatisticsRepository {
  /// Returns the consumed/discarded [StatusChangeRecord]s of [householdId]
  /// whose [StatusChangeRecord.statusChangedAt] lies in `[from, to]`.
  /// Newest records first, limited to [limit] (default 2 000) to keep reads
  /// bounded. Throws a `Failure` on error.
  Future<List<StatusChangeRecord>> getStatusChangeRecords({
    required String householdId,
    required DateTime from,
    DateTime? to,
    int limit,
  });
}
