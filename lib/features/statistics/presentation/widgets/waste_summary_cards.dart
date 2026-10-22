import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
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
    final isHighWaste = stats.isHighWaste;

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content-driven height (with a floor) so the cards never overflow
          // on short or wide screens.
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 92.r),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: StatisticCard(
                      title: 'Đã dùng',
                      count: stats.totalConsumed,
                      bgColor: AppColors.emerald50,
                      iconColor: AppColors.emerald500,
                      icon: LucideIcons.checkCircle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: StatisticCard(
                      title: 'Đã vứt',
                      count: stats.totalDiscarded,
                      bgColor: AppColors.red50,
                      iconColor: AppColors.red500,
                      icon: LucideIcons.trash2,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: StatisticCard(
                      title: 'Lãng phí',
                      count: 0,
                      value: rateText,
                      bgColor: isHighWaste
                          ? AppColors.amber50
                          : AppColors.emerald50,
                      iconColor: isHighWaste
                          ? AppColors.amber600
                          : AppColors.emerald500,
                      icon: LucideIcons.pieChart,
                    ),
                  ),
                ],
              ),
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
