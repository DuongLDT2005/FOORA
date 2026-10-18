import '../../../../core/constants/app_enums.dart';
import '../../../membership/domain/repositories/membership_repository.dart';
import '../entities/receipt_scan_quota.dart';
import '../repositories/receipt_repository.dart';

/// Streams the current user's receipt-scan quota.
///
/// Entitlement is resolved from the active subscription (source of truth per
/// docs/DATABASE.md), never from the cached `users.membershipId`. The limit is
/// read from the membership configuration in Firestore.
class WatchReceiptScanQuotaUseCase {
  final MembershipRepository membershipRepository;
  final ReceiptRepository receiptRepository;

  const WatchReceiptScanQuotaUseCase({
    required this.membershipRepository,
    required this.receiptRepository,
  });

  Stream<ReceiptScanQuota> call({DateTime? now}) {
    final period = usagePeriodOf(now ?? DateTime.now());
    return membershipRepository.watchPremiumSubscription().asyncExpand((
      subscription,
    ) async* {
      final membershipId =
          subscription?.membershipId ?? MembershipTier.free.value;
      final plan = await membershipRepository.getMembershipPlan(membershipId);
      yield* receiptRepository
          .watchMonthlyScanUsage(period: period)
          .map(
            (used) => ReceiptScanQuota(
              scansUsed: used,
              scanLimit: plan.receiptScanQuota,
            ),
          );
    });
  }

  /// Usage period key shared with the backend, e.g. `2026-09`.
  static String usagePeriodOf(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
