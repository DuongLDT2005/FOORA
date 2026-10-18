import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Card describing the user's current plan.
class CurrentPlanCard extends StatelessWidget {
  const CurrentPlanCard({
    super.key,
    required this.isPremium,
    required this.scanLimit,
  });

  final bool isPremium;

  /// Monthly receipt-scan quota of the plan; `null` means unlimited.
  final int? scanLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: isPremium ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isPremium ? AppColors.primary : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isPremium)
            Positioned(
              right: -22.w,
              bottom: -26.h,
              child: Icon(
                LucideIcons.sparkles,
                size: 112.r,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GÓI HIỆN TẠI',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: isPremium
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.slate400,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                isPremium ? 'Premium' : 'Free',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: isPremium ? Colors.white : AppColors.slate800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                isPremium
                    ? 'Bạn đang sử dụng gói Premium với tính năng quét hóa đơn không giới hạn.'
                    : scanLimit == null
                    ? 'Sử dụng các tính năng quản lý thực phẩm cốt lõi của FOORA.'
                    : 'Sử dụng các tính năng quản lý thực phẩm cốt lõi của FOORA với $scanLimit lượt quét hóa đơn mỗi tháng.',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13.sp,
                  height: 1.45,
                  color: isPremium
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Progress bar of AI receipt scans used this month (Free plan).
class QuotaProgressCard extends StatelessWidget {
  const QuotaProgressCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.used,
    required this.limit,
    required this.unit,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final int used;

  /// Plan limit; `null` means unlimited (no progress bar fill).
  final int? limit;
  final String unit;
  final String description;

  @override
  Widget build(BuildContext context) {
    final limit = this.limit;
    final progress = limit == null || limit <= 0
        ? 0.0
        : (used / limit).clamp(0.0, 1.0);

    return MembershipWhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16.r, color: iconColor),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
              ),
              Text(
                limit == null ? '$used $unit' : '$used/$limit $unit',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10.h,
              value: progress,
              backgroundColor: AppColors.slate100,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card shown to Premium users: unlimited AI scans.
class UnlimitedScanCard extends StatelessWidget {
  const UnlimitedScanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return MembershipWhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 16.r, color: AppColors.amber500),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Hạn mức quét hóa đơn',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Không giới hạn',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.amber600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.amber50.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.amber200.withValues(alpha: 0.65),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.sparkles,
                  size: 16.r,
                  color: AppColors.amber600,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quét hóa đơn thả ga',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amber800,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Thoải mái thêm thực phẩm tự động bằng công nghệ nhận diện hình ảnh với gói Premium.',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 12.sp,
                          color: AppColors.amber800.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium package details: plan name, start and end date.
///
/// payOS subscriptions never auto-renew (`autoRenew` is always `false` per
/// docs/DATABASE.md), so the user renews by paying again.
class PackageInfoCard extends StatelessWidget {
  const PackageInfoCard({
    super.key,
    required this.planName,
    required this.startDate,
    required this.endDate,
  });

  final String planName;
  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(BuildContext context) {
    return MembershipWhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.calendarDays,
                size: 16.r,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Thông tin gói',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _InfoRow(label: 'Gói đăng ký', value: 'FOORA $planName', bold: true),
          _InfoRow(
            label: 'Ngày bắt đầu',
            value: DateFormatter.formatDate(startDate),
          ),
          _InfoRow(
            label: 'Ngày hết hạn',
            value: DateFormatter.formatDate(endDate),
          ),
          SizedBox(height: 10.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Gói không tự động gia hạn. Bạn có thể thanh toán lại để '
              'gia hạn thêm trước hoặc sau khi gói hết hạn.',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11.sp,
                height: 1.4,
                color: AppColors.slate400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label / value row.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13.sp,
                color: AppColors.slate500,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 14.sp,
              color: AppColors.slate800,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase section label.
class MembershipSectionLabel extends StatelessWidget {
  const MembershipSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.slate400,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// White rounded container used by the membership cards.
class MembershipWhiteCard extends StatelessWidget {
  const MembershipWhiteCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.025),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: child,
    );
  }
}
