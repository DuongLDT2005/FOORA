import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/membership/domain/entities/membership_plan.dart';
import 'package:foora/features/membership/domain/repositories/membership_repository.dart';
import 'package:foora/features/membership/domain/usecases/get_membership_plans.dart';

class _FakeMembershipRepository implements MembershipRepository {
  final MembershipPlan plan;
  String? requestedMembershipId;

  _FakeMembershipRepository(this.plan);

  @override
  Future<MembershipPlan> getMembershipPlan(String membershipId) async {
    requestedMembershipId = membershipId;
    return plan;
  }
}

void main() {
  test('GetMembershipPlanUseCase returns the configured plan', () async {
    final now = DateTime(2026, 1, 1);
    final plan = MembershipPlan(
      id: 'free',
      name: 'Free',
      price: 0,
      foodLimit: 50,
      receiptScanQuota: 5,
      createdAt: now,
      updatedAt: now,
    );
    final repository = _FakeMembershipRepository(plan);
    final useCase = GetMembershipPlanUseCase(repository);

    final result = await useCase('free');

    expect(result, plan);
    expect(repository.requestedMembershipId, 'free');
  });
}
