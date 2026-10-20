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

  /// Returns all consumed/discarded records within the given period.
  /// If [from] is provided, uses [from] and optional [to].
  /// Otherwise falls back to the past [months] months in Vietnam time.
  Future<List<StatusChangeRecord>> call({
    required String householdId,
    DateTime? from,
    DateTime? to,
    int? months,
  }) {
    DateTime startUtc;
    DateTime? toUtc;

    if (from != null) {
      startUtc = from.isUtc ? from : from.toUtc();
      if (to != null) {
        toUtc = to.isUtc ? to : to.toUtc();
      }
    } else {
      final effectiveMonths = months ?? 6;
      final nowVn = DateTime.now().toUtc().add(_vnOffset);
      final startVn = DateTime(
        nowVn.year,
        nowVn.month - (effectiveMonths - 1),
        1,
      );
      startUtc = startVn.subtract(_vnOffset);
    }

    return _repository.getStatusChangeRecords(
      householdId: householdId,
      from: startUtc,
      to: toUtc,
      limit: _maxRecords,
    );
  }
}
