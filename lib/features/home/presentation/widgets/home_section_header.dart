import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/routes/route_names.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final Color barColor;
  final bool showSeeAll;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.barColor,
    this.showSeeAll = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: () {
                context.pushNamed(AppRouteNames.expirationManagement);
              },
              child: Container(
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
                    Text(
                      'Tất cả',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 10.sp,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
