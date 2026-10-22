import '../entities/stats_period.dart';
import '../entities/status_change_record.dart';
import '../repositories/statistics_repository.dart';

/// Use case that fetches the [StatusChangeRecord]s of a [StatsPeriod].
/// At most [maxRecords] records are returned, newest first.
class GetStatusChangeRecords {
  const GetStatusChangeRecords(this._repository);

  final StatisticsRepository _repository;

  static const int maxRecords = 2000;

  Future<List<StatusChangeRecord>> call({
    required String householdId,
    required StatsPeriod period,
  }) {
    return _repository.getStatusChangeRecords(
      householdId: householdId,
      from: period.startUtc,
      to: period.endUtc,
      limit: maxRecords,
    );
  }
}
