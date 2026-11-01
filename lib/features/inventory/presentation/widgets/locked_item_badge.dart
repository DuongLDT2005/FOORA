import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';

/// Badge for an item locked by the Free plan's food limit.
class LockedItemBadge extends StatelessWidget {
  const LockedItemBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.lock, size: 10.r, color: AppColors.slate600),
          SizedBox(width: 2.w),
          Text(
            'ĐÃ KHÓA',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: AppColors.slate600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
