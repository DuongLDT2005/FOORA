import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ExpirationStatsBoard extends StatelessWidget {
  final int urgentCount;
  final int spoiledCount;

  const ExpirationStatsBoard({
    super.key,
    required this.urgentCount,
    required this.spoiledCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Cần dùng gấp',
            value: urgentCount.toString(),
            subtitle: 'Sắp hết hạn trong 3 ngày',
            icon: LucideIcons.alertTriangle,
            backgroundColor: AppColors.amber50,
            borderColor: AppColors.amber100,
            textColor: AppColors.amber700,
            valueColor: AppColors.amber600,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _StatCard(
            title: 'Đã hỏng',
            value: spoiledCount.toString(),
            subtitle: 'Không đảm bảo an toàn',
            icon: LucideIcons.shieldAlert,
            backgroundColor: AppColors.red50,
            borderColor: AppColors.red100,
            textColor: AppColors.red700,
            valueColor: AppColors.red600,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12.sp, color: textColor),
              SizedBox(width: 6.w),
              Text(
                title.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.headlineLarge.copyWith(
              fontSize: 30.sp,
              fontWeight: FontWeight.w900,
              color: valueColor,
              height: 1.0,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
