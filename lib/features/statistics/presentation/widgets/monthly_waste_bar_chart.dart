import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../domain/entities/waste_statistics.dart';

/// Bar chart showing consumed vs. discarded item counts per month.
/// Each month has two side-by-side bars: emerald (consumed) and red (discarded).
/// When [months] is 12, the chart scrolls horizontally.
class MonthlyWasteBarChart extends StatelessWidget {
  const MonthlyWasteBarChart({
    super.key,
    required this.monthly,
    required this.months,
  });

  final List<MonthlyWaste> monthly;
  final int months;

  static const _consumed = AppColors.emerald500;
  static const _discarded = AppColors.red500;
  static const _barWidth = 10.0;

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) return const SizedBox.shrink();

    final maxY = monthly
        .map((m) => m.consumed > m.discarded ? m.consumed : m.discarded)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();
    final chartMaxY = (maxY < 4 ? 4 : maxY + 1).toDouble();

    Widget chart = BarChart(
      BarChartData(
        maxY: chartMaxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.slate800.withValues(alpha: 0.9),
            tooltipPadding: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 6.h,
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = monthly[groupIndex];
              final label = rodIndex == 0
                  ? 'Đã dùng: ${month.consumed} lô'
                  : 'Đã vứt: ${month.discarded} lô';
              return BarTooltipItem(
                label,
                TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28.h,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= monthly.length) return const SizedBox();
                return Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Text(
                    monthly[idx].label,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28.w,
              interval: chartMaxY > 8 ? (chartMaxY / 4).ceilToDouble() : 2,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10.sp, color: AppColors.slate300),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMaxY > 8
              ? (chartMaxY / 4).ceilToDouble()
              : 2,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.slate100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: monthly.asMap().entries.map((e) {
          final i = e.key;
          final m = e.value;
          return BarChartGroupData(
            x: i,
            barsSpace: 4.w,
            barRods: [
              BarChartRodData(
                toY: m.consumed.toDouble(),
                color: _consumed,
                width: _barWidth.w,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
              ),
              BarChartRodData(
                toY: m.discarded.toDouble(),
                color: _discarded,
                width: _barWidth.w,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
              ),
            ],
          );
        }).toList(),
      ),
    );

    // Wrap in horizontal scroll when showing 12 months so bars don't overlap.
    final chartWidget = months >= 12
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: 50.w * months, height: 220.h, child: chart),
          )
        : SizedBox(height: 220.h, child: chart);

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartTitle(title: 'Tiêu thụ theo tháng'),
          SizedBox(height: 12.h),
          chartWidget,
          SizedBox(height: 10.h),
          // Legend
          Row(
            children: [
              _LegendDot(color: _consumed, label: 'Đã dùng'),
              SizedBox(width: 16.w),
              _LegendDot(color: _discarded, label: 'Đã vứt'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10.r,
          height: 10.r,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: AppColors.slate500),
        ),
      ],
    );
  }
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Lexend',
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.slate700,
      ),
    );
  }
}
