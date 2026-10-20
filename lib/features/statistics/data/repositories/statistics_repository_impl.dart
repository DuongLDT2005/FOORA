import '../../domain/entities/status_change_record.dart';
import '../../domain/repositories/statistics_repository.dart';
import '../datasources/statistics_remote_datasource.dart';

class StatisticsRepositoryImpl implements StatisticsRepository {
  const StatisticsRepositoryImpl({required this.dataSource});

  final StatisticsRemoteDataSource dataSource;

  @override
  Future<List<StatusChangeRecord>> getStatusChangeRecords({
    required String householdId,
    required DateTime from,
    int limit = 2000,
  }) {
    return dataSource.getStatusChangeRecords(
      householdId: householdId,
      from: from,
      limit: limit,
    );
  }
}
