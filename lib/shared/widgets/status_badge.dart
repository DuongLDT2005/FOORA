import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

// --- StatusBadge ---
class StatusBadge extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.bgColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.expired() => const StatusBadge(
    text: 'Hết hạn',
    bgColor: Color(0xFFFEF2F2),
    textColor: AppColors.red500,
  );

  factory StatusBadge.warning() => const StatusBadge(
    text: 'Sắp hết',
    bgColor: Color(0xFFFFFBEB),
    textColor: AppColors.amber500,
  );

  factory StatusBadge.premium() => const StatusBadge(
    text: 'PREMIUM',
    bgColor: Color(0xFFFFFBEB),
    textColor: AppColors.amber500,
    icon: Icons.star,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.r, color: textColor),
            SizedBox(width: 4.w),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// --- CategoryAvatar ---
class CategoryAvatar extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final double size;

  const CategoryAvatar({
    super.key,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size.r;
    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(effectiveSize * 0.3),
      ),
      child: Icon(icon, color: iconColor, size: effectiveSize * 0.5),
    );
  }
}
