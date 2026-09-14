import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

// --- EmptyStateWidget ---
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    this.title = 'Tủ đang trống hoặc không có kết quả!',
    this.subtitle =
        'Hãy nhấn Thêm nhanh hoặc quét mã để lấp đầy tủ lạnh của bạn.',
    this.icon = Icons.sentiment_dissatisfied,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40.r, color: AppColors.slate300),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Lexend',
              color: AppColors.slate700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: AppColors.slate400),
          ),
          if (action != null) ...[SizedBox(height: 16.h), action!],
        ],
      ),
    );
  }
}
