import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/status_change_record.dart';
import '../../domain/repositories/statistics_repository.dart';
import '../datasources/statistics_remote_datasource.dart';

/// Implementation of [StatisticsRepository] on top of
/// [StatisticsRemoteDataSource]. Maps data-layer exceptions to [Failure]s.
class StatisticsRepositoryImpl implements StatisticsRepository {
  const StatisticsRepositoryImpl({required this.dataSource});

  final StatisticsRemoteDataSource dataSource;

  @override
  Future<List<StatusChangeRecord>> getStatusChangeRecords({
    required String householdId,
    required DateTime from,
    DateTime? to,
    int limit = 2000,
  }) async {
    try {
      return await dataSource.getStatusChangeRecords(
        householdId: householdId,
        from: from,
        to: to,
        limit: limit,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (_) {
      throw const ServerFailure(
        'Không thể tải dữ liệu thống kê. Vui lòng thử lại.',
      );
    }
  }
}
