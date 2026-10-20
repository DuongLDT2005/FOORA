import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../domain/entities/waste_statistics.dart';

/// Three summary metric cards: consumed count, discarded count, waste rate %.
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
      child: Row(
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
          SizedBox(width: 10.w),
          Expanded(
            child: _SummaryCard(
              label: 'Đã vứt',
              value: '${stats.totalDiscarded}',
              unit: 'lô',
              subtitle: stats.discardedAfterExpiry > 0
                  ? '${stats.discardedAfterExpiry} lô quá hạn'
                  : null,
              icon: LucideIcons.trash2,
              color: AppColors.red500,
              bgColor: AppColors.red50,
            ),
          ),
          SizedBox(width: 10.w),
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
    this.subtitle,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
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
          SizedBox(height: 8.h),
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
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  SizedBox(width: 2.w),
                  Padding(
                    padding: EdgeInsets.only(bottom: 3.h),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.slate400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.slate400,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 9.sp, color: AppColors.red500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
