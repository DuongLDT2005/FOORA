import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/membership_plan.dart';
import '../../domain/repositories/membership_repository.dart';
import '../datasources/membership_remote_datasource.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  final MembershipRemoteDataSource remoteDataSource;

  MembershipRepositoryImpl({required this.remoteDataSource});

  @override
  Future<MembershipPlan> getMembershipPlan(String membershipId) async {
    try {
      return await remoteDataSource.getMembershipPlan(membershipId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(error.toString());
    }
  }
}
