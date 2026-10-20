import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../domain/entities/waste_statistics.dart';
import '../providers/waste_statistics_provider.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/top_wasted_foods_list.dart';
import '../widgets/waste_ratio_pie_chart.dart';
import '../widgets/waste_summary_cards.dart';

/// Waste Statistics page accessible from the Profile menu and the HomeStatsBoard.
/// Displays consumed/discarded counts, waste rate %, and top-5 wasted foods
/// for a user-selected custom date range.
class WasteStatisticsPage extends ConsumerStatefulWidget {
  const WasteStatisticsPage({super.key});

  @override
  ConsumerState<WasteStatisticsPage> createState() =>
      _WasteStatisticsPageState();
}

class _WasteStatisticsPageState extends ConsumerState<WasteStatisticsPage> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to the past 30 days
    _startDate = now.subtract(const Duration(days: 29));
    _endDate = now;
  }

  DateRangeParam get _currentRange =>
      DateRangeParam(startDate: _startDate, endDate: _endDate);

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(wasteStatisticsProvider(_currentRange));

    return SubpageLayout(
      header: AppHeader(title: 'Thống kê lãng phí'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(wasteStatisticsProvider(_currentRange));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateRangeSelector(
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeChanged: (start, end) {
                  setState(() {
                    _startDate = start;
                    _endDate = end;
                  });
                },
              ),
              statsAsync.when(
                data: (stats) => _StatsBody(stats: stats),
                loading: () => _ShimmerSkeleton(),
                error: (e, _) => Padding(
                  padding: EdgeInsets.only(top: 48.h),
                  child: ErrorStateWidget(
                    message: 'Không thể tải dữ liệu thống kê.',
                    onRetry: () =>
                        ref.invalidate(wasteStatisticsProvider(_currentRange)),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Body when data loaded ───────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final WasteStatistics stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WasteSummaryCards(stats: stats),
        WasteRatioPieChart(stats: stats),
        TopWastedFoodsList(topWasted: stats.topWasted),
        if (!stats.hasData) const _EmptyHint(),
        if (stats.totalResolved >= 2000) _LimitNotice(),
      ],
    );
  }
}

// ─── Empty & limit notices ───────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 56.r,
              color: AppColors.slate200,
            ),
            SizedBox(height: 12.h),
            Text(
              'Chưa có dữ liệu trong khoảng thời gian này',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.slate400,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Hãy dùng hoặc vứt bỏ thực phẩm\nđể bắt đầu tạo thống kê.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: AppColors.slate300),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h, bottom: 8.h),
      child: Text(
        '⚠ Chỉ tính 2.000 lô gần nhất trong kỳ.',
        style: TextStyle(fontSize: 11.sp, color: AppColors.amber600),
      ),
    );
  }
}

// ─── Shimmer loading skeleton ─────────────────────────────────────────────────

class _ShimmerSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBox(height: 90.h),
        SizedBox(height: 14.h),
        _SkeletonBox(height: 180.h),
        SizedBox(height: 14.h),
        _SkeletonBox(height: 200.h),
      ],
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.height});
  final double height;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Opacity(
        opacity: _anim.value,
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.slate100,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
      ),
    );
  }
}
