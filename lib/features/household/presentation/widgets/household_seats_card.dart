import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../membership/presentation/providers/membership_provider.dart';

/// Owner-only card showing used/available seats of the household, based on
/// the owner's plan (`memberships/{id}.memberLimit`), with an upgrade call to
/// action for Free owners. Display only: the backend enforces the limit.
class HouseholdSeatsCard extends ConsumerWidget {
  final int memberCount;

  /// Set when shown inside a modal (bottom sheet) that must close before the
  /// upgrade page is pushed.
  final bool closeBeforeUpgrade;

  const HouseholdSeatsCard({
    super.key,
    required this.memberCount,
    this.closeBeforeUpgrade = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final plan = ref
        .watch(membershipPlanProvider(user.membershipId))
        .valueOrNull;
    if (plan == null) return const SizedBox.shrink();
    final premiumPlan = user.isPremium
        ? plan
        : ref
              .watch(membershipPlanProvider(MembershipTier.premium.value))
              .valueOrNull;

    final limit = plan.memberLimit;
    final isFull = limit != null && memberCount >= limit;
    final premiumLimit = premiumPlan?.memberLimit;

    final String title = limit == null
        ? '$memberCount thành viên • gói ${plan.name}'
        : '$memberCount/$limit thành viên • gói ${plan.name}';
    final String subtitle;
    if (user.isPremium) {
      subtitle = isFull
          ? 'Gia đình đã đạt số thành viên tối đa của gói ${plan.name}.'
          : 'Bạn có thể mời thêm ${limit == null ? 'thành viên' : '${limit - memberCount} người'}.';
    } else if (isFull) {
      subtitle = premiumLimit == null
          ? 'Đã đủ chỗ. Nâng cấp Premium để mời thêm thành viên.'
          : 'Đã đủ chỗ. Nâng cấp Premium để chia sẻ với tối đa $premiumLimit người.';
    } else {
      subtitle = premiumLimit == null
          ? 'Nâng cấp Premium để mời thêm thành viên.'
          : 'Nâng cấp Premium để chia sẻ với tối đa $premiumLimit người.';
    }

    final accent = isFull ? AppColors.amber700 : AppColors.primary;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: isFull ? AppColors.amber50 : AppColors.emerald50,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isFull ? AppColors.amber200 : AppColors.emerald100,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFull ? LucideIcons.users : LucideIcons.userPlus,
            size: 20.r,
            color: accent,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilySans,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilySans,
                    fontSize: 12.sp,
                    color: AppColors.slate600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (!user.isPremium) ...[
            SizedBox(width: 8.w),
            TextButton(
              onPressed: () {
                // Grab the router first: the sheet's context is torn down
                // once it is popped.
                final router = GoRouter.of(context);
                if (closeBeforeUpgrade) Navigator.of(context).pop();
                router.push(AppRouteNames.membership);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.surfaceContainerLowest,
                backgroundColor: accent,
                minimumSize: Size(0, 44.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'Nâng cấp',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamilySans,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
