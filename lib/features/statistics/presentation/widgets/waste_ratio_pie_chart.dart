import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../domain/entities/waste_statistics.dart';

/// Pie chart showing the share of consumed vs. discarded batches.
/// Hidden automatically when there is no data (totalResolved == 0).
class WasteRatioPieChart extends StatelessWidget {
  const WasteRatioPieChart({super.key, required this.stats});

  final WasteStatistics stats;

  @override
  Widget build(BuildContext context) {
    if (!stats.hasData) return const SizedBox.shrink();

    final consumed = stats.totalConsumed.toDouble();
    final discarded = stats.totalDiscarded.toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.slate100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tỷ lệ tổng quan',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.slate700,
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                SizedBox(
                  width: 130.r,
                  height: 130.r,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 38.r,
                          sections: [
                            PieChartSectionData(
                              value: consumed,
                              color: AppColors.emerald500,
                              radius: 22.r,
                              title: '',
                            ),
                            PieChartSectionData(
                              value: discarded,
                              color: AppColors.red500,
                              radius: 22.r,
                              title: '',
                            ),
                          ],
                        ),
                      ),
                      // Center label: waste rate %
                      Positioned.fill(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  stats.wasteRatePercent != null
                                      ? '${stats.wasteRatePercent!.toStringAsFixed(1)}%'
                                      : '—',
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w900,
                                    color: (stats.wasteRatePercent ?? 0) > 20
                                        ? AppColors.red500
                                        : AppColors.emerald500,
                                  ),
                                ),
                                Text(
                                  'lãng phí',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PieLegendRow(
                        color: AppColors.emerald500,
                        label: 'Đã dùng',
                        count: stats.totalConsumed,
                        total: stats.totalResolved,
                      ),
                      SizedBox(height: 12.h),
                      _PieLegendRow(
                        color: AppColors.red500,
                        label: 'Đã vứt',
                        count: stats.totalDiscarded,
                        total: stats.totalResolved,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PieLegendRow extends StatelessWidget {
  const _PieLegendRow({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  final Color color;
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
    return Row(
      children: [
        Container(
          width: 12.r,
          height: 12.r,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label ($pct%)',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
              SizedBox(height: 4.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: total > 0 ? count / total : 0,
                  backgroundColor: AppColors.slate100,
                  color: color,
                  minHeight: 6.h,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
