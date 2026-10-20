import '../entities/status_change_record.dart';

/// Domain repository interface for fetching raw inventory status-change records
/// from the data source. The implementation lives in the data layer.
abstract class StatisticsRepository {
  /// Returns all [StatusChangeRecord]s for [householdId] whose [statusChangedAt]
  /// is on or after [from]. Only consumed and discarded items are returned.
  /// Limited to [limit] records (default 2 000) to keep reads bounded.
  Future<List<StatusChangeRecord>> getStatusChangeRecords({
    required String householdId,
    required DateTime from,
    int limit,
  });
}
