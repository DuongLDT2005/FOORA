import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../domain/entities/waste_statistics.dart';

/// Three summary metric cards: consumed count, discarded count, waste rate %.
/// Balanced with equal height, uniform layout, and aligned baselines.
class WasteSummaryCards extends StatelessWidget {
  const WasteSummaryCards({super.key, required this.stats});

  final WasteStatistics stats;

  @override
  Widget build(BuildContext context) {
    final rateText = stats.wasteRatePercent != null
        ? '${stats.wasteRatePercent!.toStringAsFixed(1)}%'
        : '—';
    final rateColor = (stats.wasteRatePercent ?? 0) > 20
        ? AppColors.red500
        : AppColors.emerald500;

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Đã dùng',
                    value: '${stats.totalConsumed}',
                    unit: 'lô',
                    icon: LucideIcons.checkCircle,
                    color: AppColors.emerald500,
                    bgColor: AppColors.emerald50,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _SummaryCard(
                    label: 'Đã vứt',
                    value: '${stats.totalDiscarded}',
                    unit: 'lô',
                    icon: LucideIcons.trash2,
                    color: AppColors.red500,
                    bgColor: AppColors.red50,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _SummaryCard(
                    label: 'Lãng phí',
                    value: rateText,
                    unit: '',
                    icon: LucideIcons.pieChart,
                    color: rateColor,
                    bgColor: (stats.wasteRatePercent ?? 0) > 20
                        ? AppColors.red50
                        : AppColors.emerald50,
                  ),
                ),
              ],
            ),
          ),
          if (stats.discardedAfterExpiry > 0) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.red50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.red100),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 14.r, color: AppColors.red500),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Trong đó có ${stats.discardedAfterExpiry} lô bị vứt do quá hạn',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.red500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 16.r),
          ),
          SizedBox(height: 10.h),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      SizedBox(width: 2.w),
                      Padding(
                        padding: EdgeInsets.only(bottom: 2.h),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
