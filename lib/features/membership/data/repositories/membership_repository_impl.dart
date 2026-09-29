import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/membership_plan.dart';
import '../../domain/entities/subscription.dart';
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

  @override
  Stream<Subscription?> watchPremiumSubscription() {
    return remoteDataSource.watchPremiumSubscription();
  }

  @override
  Future<void> updateAutoRenew(bool enabled) async {
    try {
      await remoteDataSource.updateAutoRenew(enabled);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(error.toString());
    }
  }
}
