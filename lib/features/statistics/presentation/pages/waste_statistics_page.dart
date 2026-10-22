import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/components/app_shimmer.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../domain/entities/stats_period.dart';
import '../../domain/entities/waste_statistics.dart';
import '../../domain/usecases/get_status_change_records.dart';
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
    // Default to the past 30 days (Vietnam calendar).
    final today = StatsPeriod.todayVn();
    _startDate = DateTime(today.year, today.month, today.day - 29);
    _endDate = today;
  }

  DateRangeParam get _currentRange =>
      DateRangeParam(startDate: _startDate, endDate: _endDate);

  Future<void> _refresh() async {
    try {
      ref.invalidate(wasteStatisticsProvider(_currentRange));
      await ref.read(wasteStatisticsProvider(_currentRange).future);
    } catch (_) {
      // The error state is rendered from the provider; nothing to do here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(wasteStatisticsProvider(_currentRange));

    return SubpageLayout(
      header: AppHeader(title: 'Thống kê lãng phí'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
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
                loading: () => const _LoadingSkeleton(),
                error: (e, _) => Padding(
                  padding: EdgeInsets.only(top: 48.h),
                  child: ErrorStateWidget(
                    message: e is Failure
                        ? e.message
                        : 'Không thể tải dữ liệu thống kê.',
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
    if (!stats.hasData) {
      return const EmptyStateWidget(
        title: 'Chưa có dữ liệu trong khoảng thời gian này',
        subtitle: 'Hãy dùng hoặc vứt bỏ thực phẩm để bắt đầu tạo thống kê.',
        icon: LucideIcons.pieChart,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WasteSummaryCards(stats: stats),
        WasteRatioPieChart(stats: stats),
        TopWastedFoodsList(topWasted: stats.topWasted),
        if (stats.isTruncated) const _LimitNotice(),
      ],
    );
  }
}

// ─── Limit notice ────────────────────────────────────────────────────────────

class _LimitNotice extends StatelessWidget {
  const _LimitNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h, bottom: 8.h),
      child: Text(
        '⚠ Chỉ tính ${GetStatusChangeRecords.maxRecords} lô gần nhất trong kỳ.',
        style: TextStyle(fontSize: 12.sp, color: AppColors.amber600),
      ),
    );
  }
}

// ─── Shimmer loading skeleton ─────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmer.box(
          width: double.infinity,
          height: 90.h,
          borderRadius: 16.r,
        ),
        SizedBox(height: 14.h),
        AppShimmer.box(
          width: double.infinity,
          height: 180.h,
          borderRadius: 16.r,
        ),
        SizedBox(height: 14.h),
        AppShimmer.box(
          width: double.infinity,
          height: 200.h,
          borderRadius: 16.r,
        ),
      ],
    );
  }
}
