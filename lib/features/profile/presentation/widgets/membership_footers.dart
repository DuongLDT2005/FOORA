import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Bottom bar for Free users with the upgrade button.
class MembershipFreeFooter extends StatelessWidget {
  const MembershipFreeFooter({
    super.key,
    required this.price,
    required this.durationDays,
    required this.onUpgrade,
  });

  /// Premium price and duration from `memberships/premium`; `null` while loading.
  final double? price;
  final int? durationDays;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final price = this.price;
    final formattedPrice = price == null
        ? '—'
        : CurrencyFormatter.formatVND(price, showFreeText: false);
    final durationDays = this.durationDays;
    final periodLabel = durationDays == null
        ? ''
        : durationDays == 30
        ? '/ tháng'
        : '/ $durationDays ngày';

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GÓI PREMIUM',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 11.sp,
                color: AppColors.slate400,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedPrice,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate800,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h, left: 4.w),
                  child: Text(
                    periodLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 14.sp,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'Nâng cấp Premium',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontFamily: AppTextStyles.fontFamilyHeadline,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar for Premium users (payment history link).
class MembershipPremiumFooter extends StatelessWidget {
  const MembershipPremiumFooter({super.key, required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56.h,
          child: OutlinedButton(
            onPressed: onManage,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.slate100,
              foregroundColor: AppColors.slate700,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              'Quản lý gói',
              style: AppTextStyles.bodyMedium.copyWith(
                fontFamily: AppTextStyles.fontFamilyHeadline,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.slate700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
