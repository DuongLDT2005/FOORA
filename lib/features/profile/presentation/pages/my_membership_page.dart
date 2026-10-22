import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../household/presentation/providers/household_provider.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../membership/domain/entities/membership_plan.dart';
import '../../../membership/domain/entities/subscription.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../receipt/presentation/providers/receipt_scan_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/membership_benefits.dart';
import '../widgets/membership_cards.dart';
import '../widgets/membership_footers.dart';

/// "Gói thành viên" screen. Shows a different layout for Free and Premium
/// users: current plan, AI-scan quota, benefits, plan comparison and actions.
///
/// Premium entitlement is resolved from the active subscription (source of
/// truth per docs/DATABASE.md); every limit and price comes from the
/// `memberships` configuration in Firestore.
class MyMembershipPage extends ConsumerWidget {
  const MyMembershipPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileStreamProvider);

    return profileAsync.when(
      loading: () => _loadingPage(context),
      error: (_, _) => _errorPage(
        context,
        onRetry: () => ref.invalidate(currentProfileStreamProvider),
      ),
      data: (profile) {
        if (profile == null) return _missingProfilePage(context);

        final subscriptionAsync = ref.watch(premiumSubscriptionProvider);
        return subscriptionAsync.when(
          loading: () => _loadingPage(context),
          error: (_, _) => _errorPage(
            context,
            onRetry: () => ref.invalidate(premiumSubscriptionProvider),
          ),
          data: (subscription) {
            final membershipId =
                subscription?.membershipId ?? MembershipTier.free.value;
            final planAsync = ref.watch(membershipPlanProvider(membershipId));

            return planAsync.when(
              loading: () => _loadingPage(context),
              error: (_, _) => _errorPage(
                context,
                onRetry: () =>
                    ref.invalidate(membershipPlanProvider(membershipId)),
              ),
              data: (plan) => subscription != null
                  ? _PremiumMembershipView(
                      plan: plan,
                      subscription: subscription,
                      onBack: () => _handleBack(context),
                    )
                  : _FreeMembershipView(
                      plan: plan,
                      onBack: () => _handleBack(context),
                    ),
            );
          },
        );
      },
    );
  }

  /// Pops the page, or goes to Profile if there is nothing to pop.
  static void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouteNames.profile);
  }

  Widget _loadingPage(BuildContext context) {
    return SubpageLayout(
      header: AppHeader.membership(onBack: () => _handleBack(context)),
      body: const Center(
        child: LoadingWidget(message: 'Đang tải thông tin gói...'),
      ),
    );
  }

  Widget _errorPage(BuildContext context, {required VoidCallback onRetry}) {
    return SubpageLayout(
      header: AppHeader.membership(onBack: () => _handleBack(context)),
      body: ErrorStateWidget(
        message: 'Không thể tải thông tin gói thành viên.',
        onRetry: onRetry,
      ),
    );
  }

  Widget _missingProfilePage(BuildContext context) {
    return SubpageLayout(
      header: AppHeader.membership(onBack: () => _handleBack(context)),
      body: const Center(child: Text('Không tìm thấy hồ sơ người dùng.')),
    );
  }
}

/// Layout for Free users: quota usage, free benefits, comparison, upgrade CTA.
class _FreeMembershipView extends ConsumerWidget {
  const _FreeMembershipView({required this.plan, required this.onBack});

  final MembershipPlan plan;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumPlan = ref
        .watch(membershipPlanProvider(MembershipTier.premium.value))
        .valueOrNull;
    final foodCount =
        ref.watch(activeHouseholdInventoryStreamProvider).valueOrNull?.length ??
        0;
    final scansUsed =
        ref.watch(receiptQuotaProvider).valueOrNull?.scansUsed ?? 0;
    final foodLimit = plan.foodLimit;
    final scanLimit = plan.receiptScanQuota;
    // A shared household uses its owner's plan for the food limit, so this
    // user's own limit does not apply while another member's kitchen is active.
    final userId = ref.watch(currentUserProvider)?.id;
    final activeHousehold = ref
        .watch(currentHouseholdStreamProvider)
        .valueOrNull;
    final usesOwnerPlan =
        activeHousehold != null &&
        userId != null &&
        !activeHousehold.isOwner(userId);

    return SubpageLayout(
      header: AppHeader.membership(onBack: onBack, isPremium: false),
      bottomNavigationBar: MembershipFreeFooter(
        price: premiumPlan?.price,
        durationDays: premiumPlan?.durationDays,
        onUpgrade: () => context.push(AppRouteNames.membership),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CurrentPlanCard(isPremium: false, scanLimit: scanLimit),
            SizedBox(height: 16.h),
            QuotaProgressCard(
              icon: LucideIcons.refrigerator,
              iconColor: AppColors.primary,
              title: 'Số lượng thực phẩm',
              used: foodCount,
              limit: usesOwnerPlan ? null : foodLimit,
              unit: 'món',
              description: usesOwnerPlan
                  ? 'Tủ lạnh "${activeHousehold.name}" đang lưu $foodCount món, '
                        'hạn mức tính theo gói của chủ gia đình'
                  : foodLimit == null
                  ? 'Bạn đang lưu $foodCount món thực phẩm'
                  : 'Bạn đã dùng $foodCount/$foodLimit hạn mức lưu trữ thực phẩm',
            ),
            SizedBox(height: 16.h),
            QuotaProgressCard(
              icon: LucideIcons.sparkles,
              iconColor: AppColors.amber500,
              title: 'Hạn mức quét hóa đơn',
              used: scansUsed,
              limit: scanLimit,
              unit: 'lượt',
              description: scanLimit == null
                  ? 'Bạn đã dùng $scansUsed lượt quét hóa đơn tháng này'
                  : 'Bạn đã dùng $scansUsed/$scanLimit lượt quét hóa đơn tháng này',
            ),
            SizedBox(height: 24.h),
            const MembershipSectionLabel('FREE BAO GỒM'),
            SizedBox(height: 12.h),
            FreeBenefitsCard(
              foodLimit: foodLimit,
              scanLimit: scanLimit,
              memberLimit: plan.memberLimit,
            ),
            SizedBox(height: 24.h),
            const MembershipSectionLabel('PREMIUM CÓ GÌ KHÁC?'),
            SizedBox(height: 12.h),
            PremiumBenefitsList(memberLimit: premiumPlan?.memberLimit),
            SizedBox(height: 24.h),
            const MembershipSectionLabel('SO SÁNH GÓI'),
            SizedBox(height: 12.h),
            PlanComparisonCard(
              freeFoodLimit: foodLimit,
              freeScanLimit: scanLimit,
              freeMemberLimit: plan.memberLimit,
              premiumMemberLimit: premiumPlan?.memberLimit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Layout for Premium users: unlimited scans and package dates.
class _PremiumMembershipView extends StatelessWidget {
  const _PremiumMembershipView({
    required this.plan,
    required this.subscription,
    required this.onBack,
  });

  final MembershipPlan plan;
  final Subscription subscription;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SubpageLayout(
      header: AppHeader.membership(onBack: onBack, isPremium: true),
      bottomNavigationBar: MembershipPremiumFooter(
        onManage: () => context.push(AppRouteNames.paymentHistory),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CurrentPlanCard(isPremium: true, scanLimit: plan.receiptScanQuota),
            SizedBox(height: 24.h),
            const UnlimitedScanCard(),
            SizedBox(height: 24.h),
            PackageInfoCard(
              planName: plan.name,
              startDate: subscription.startDate,
              endDate: subscription.endDate,
            ),
            SizedBox(height: 24.h),
            const MembershipSectionLabel('QUYỀN LỢI PREMIUM'),
            SizedBox(height: 12.h),
            PremiumBenefitsList(memberLimit: plan.memberLimit),
          ],
        ),
      ),
    );
  }
}
