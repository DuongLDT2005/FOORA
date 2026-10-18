import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/membership/domain/entities/membership_plan.dart';
import 'package:foora/features/membership/domain/entities/subscription.dart';
import 'package:foora/features/membership/domain/repositories/membership_repository.dart';
import 'package:foora/features/receipt/domain/repositories/receipt_repository.dart';
import 'package:foora/features/receipt/domain/usecases/watch_receipt_scan_quota.dart';

class _FakeMembershipRepository implements MembershipRepository {
  final Subscription? subscription;
  final Map<String, MembershipPlan> plans;

  _FakeMembershipRepository({this.subscription, required this.plans});

  @override
  Future<MembershipPlan> getMembershipPlan(String membershipId) async =>
      plans[membershipId]!;

  @override
  Stream<Subscription?> watchPremiumSubscription() =>
      Stream.value(subscription);
}

class _FakeReceiptRepository implements ReceiptRepository {
  final int used;
  String? requestedPeriod;

  _FakeReceiptRepository(this.used);

  @override
  Stream<int> watchMonthlyScanUsage({required String period}) {
    requestedPeriod = period;
    return Stream.value(used);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MembershipPlan _plan(String id, int? scanQuota) {
  final now = DateTime(2026, 1, 1);
  return MembershipPlan(
    id: id,
    name: id,
    price: 0,
    receiptScanQuota: scanQuota,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final plans = {
    MembershipTier.free.value: _plan(MembershipTier.free.value, 5),
    MembershipTier.premium.value: _plan(MembershipTier.premium.value, null),
  };

  test('free user gets the limit from memberships/free', () async {
    final receipts = _FakeReceiptRepository(3);
    final useCase = WatchReceiptScanQuotaUseCase(
      membershipRepository: _FakeMembershipRepository(plans: plans),
      receiptRepository: receipts,
    );

    final quota = await useCase(now: DateTime(2026, 9, 14)).first;

    expect(quota.scansUsed, 3);
    expect(quota.scanLimit, 5);
    expect(quota.isQuotaExceeded, isFalse);
    expect(receipts.requestedPeriod, '2026-09');
  });

  test('active subscription resolves the premium plan (unlimited)', () async {
    final now = DateTime(2026, 9, 14);
    final subscription = Subscription(
      id: 'payos_premium',
      membershipId: MembershipTier.premium.value,
      provider: 'payos',
      status: SubscriptionStatus.active,
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 29)),
      createdAt: now,
      updatedAt: now,
    );
    final useCase = WatchReceiptScanQuotaUseCase(
      membershipRepository: _FakeMembershipRepository(
        subscription: subscription,
        plans: plans,
      ),
      receiptRepository: _FakeReceiptRepository(42),
    );

    final quota = await useCase(now: now).first;

    expect(quota.isUnlimited, isTrue);
    expect(quota.isQuotaExceeded, isFalse);
  });
}
