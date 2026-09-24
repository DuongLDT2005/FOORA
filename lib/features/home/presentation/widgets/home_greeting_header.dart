import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

class HomeGreetingHeader extends StatelessWidget {
  final String firstName;

  const HomeGreetingHeader({super.key, required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Hi, $firstName! 👋',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 20.sp,
              fontWeight: FontWeight.w900, // font-extrabold/black
              color: AppColors.slate800,
              letterSpacing: -0.5,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              children: [
                // Pulse dot
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald500,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Thời gian thực',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700, // font-bold
                    color: AppColors.primary,
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
