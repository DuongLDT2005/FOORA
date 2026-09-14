import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

// --- FeatureCard (Generic banner / menu card) ---
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.amber500,
    this.iconBgColor = const Color(0xFFFFFBEB), // amber-50
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.slate50)),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: iconColor, size: 20.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.slate300, size: 20.r),
          ],
        ),
      ),
    );
  }
}

// --- StatisticCard (Generic metric / summary card) ---
class StatisticCard extends StatelessWidget {
  final String title;
  final int count;
  final Color bgColor;
  final Color iconColor;
  final IconData icon;

  const StatisticCard({
    super.key,
    required this.title,
    required this.count,
    required this.bgColor,
    required this.iconColor,
    required this.icon,
  });

  factory StatisticCard.good(int count) => StatisticCard(
    title: 'Tươi mới',
    count: count,
    bgColor: const Color(0xFFF0FDF4),
    iconColor: AppColors.primary,
    icon: Icons.eco,
  );

  factory StatisticCard.warning(int count) => StatisticCard(
    title: 'Sắp hết hạn',
    count: count,
    bgColor: const Color(0xFFFFFBEB),
    iconColor: AppColors.amber500,
    icon: Icons.access_time,
  );

  factory StatisticCard.expired(int count) => StatisticCard(
    title: 'Hết hạn',
    count: count,
    bgColor: const Color(0xFFFEF2F2),
    iconColor: AppColors.red500,
    icon: Icons.warning_amber_rounded,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 20.r),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Lexend',
                  color: iconColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: iconColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
