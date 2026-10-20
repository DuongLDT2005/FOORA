import '../entities/status_change_record.dart';
import '../repositories/statistics_repository.dart';

/// Use case that fetches [StatusChangeRecord]s for the given [months] period.
/// Computes the UTC start boundary from the current time adjusted to Vietnam
/// time (UTC+7, no DST) so month buckets align with local calendar months.
class GetStatusChangeRecords {
  const GetStatusChangeRecords(this._repository);

  final StatisticsRepository _repository;

  static const int _maxRecords = 2000;
  static const Duration _vnOffset = Duration(hours: 7);

  /// Returns all consumed/discarded records from the past [months] months
  /// (inclusive of the current calendar month in Vietnam time).
  Future<List<StatusChangeRecord>> call({
    required String householdId,
    required int months,
  }) {
    final nowVn = DateTime.now().toUtc().add(_vnOffset);
    // Start of the first month of the period, in Vietnam time.
    final startVn = DateTime(nowVn.year, nowVn.month - (months - 1), 1);
    // Convert that midnight-VN boundary to UTC for the Firestore query.
    final startUtc = startVn.subtract(_vnOffset);

    return _repository.getStatusChangeRecords(
      householdId: householdId,
      from: startUtc,
      limit: _maxRecords,
    );
  }
}
