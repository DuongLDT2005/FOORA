import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';

class HomeStatsBoard extends StatelessWidget {
  final int totalCount;
  final int expiringSoonCount;
  final int expiredCount;

  const HomeStatsBoard({
    super.key,
    required this.totalCount,
    required this.expiringSoonCount,
    required this.expiredCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(
            context: context,
            title: 'Tổng sản phẩm',
            count: totalCount,
            icon: LucideIcons.layers,
            color: AppColors.emerald500,
            bgColor: AppColors.emerald50,
          ),
          SizedBox(width: 12.w),
          _buildStatCard(
            context: context,
            title: 'Sắp hết hạn',
            count: expiringSoonCount,
            icon: LucideIcons.alertTriangle,
            color: AppColors.amber500,
            bgColor: AppColors.amber50,
          ),
          SizedBox(width: 12.w),
          _buildStatCard(
            context: context,
            title: 'Đã quá hạn',
            count: expiredCount,
            icon: LucideIcons.refreshCw,
            color: AppColors.red500,
            bgColor: AppColors.red50,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        height: 112.h, // approx h-28
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.slate100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: color, size: 16.sp),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: title == 'Tổng sản phẩm'
                          ? AppColors.slate800
                          : color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.sp, // ~12px in html
                fontWeight: FontWeight.w700,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
