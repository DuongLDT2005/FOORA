import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/statistics/domain/entities/waste_statistics.dart';
import 'package:foora/features/statistics/presentation/pages/waste_statistics_page.dart';
import 'package:foora/features/statistics/presentation/providers/waste_statistics_provider.dart';
import 'package:foora/features/statistics/presentation/widgets/date_range_selector.dart';
import 'package:foora/features/statistics/presentation/widgets/waste_summary_cards.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('DateRangeSelector Widget Tests', () {
    testWidgets('renders date range and quick preset chips', (tester) async {
      DateTime start = DateTime(2026, 9, 20);
      DateTime end = DateTime(2026, 10, 20);

      await tester.pumpWidget(
        makeTestableWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return DateRangeSelector(
                startDate: start,
                endDate: end,
                onDateRangeChanged: (s, e) {
                  setState(() {
                    start = s;
                    end = e;
                  });
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Khoảng thời gian'), findsOneWidget);
      expect(find.text('20/09/2026 - 20/10/2026'), findsOneWidget);
      expect(find.text('7 ngày qua'), findsOneWidget);
      expect(find.text('30 ngày qua'), findsOneWidget);
      expect(find.text('Tháng này'), findsOneWidget);
      expect(find.text('3 tháng qua'), findsOneWidget);

      await tester.tap(find.text('7 ngày qua'));
      await tester.pumpAndSettle();
      // start has been updated to 6 days ago
      expect(end.difference(start).inDays, inInclusiveRange(5, 7));
    });
  });

  group('WasteSummaryCards Widget Tests', () {
    testWidgets(
      'renders counters and handles null wasteRatePercent with dash',
      (tester) async {
        const emptyStats = WasteStatistics(
          monthly: [],
          totalConsumed: 0,
          totalDiscarded: 0,
          discardedAfterExpiry: 0,
          topWasted: [],
          wasteRatePercent: null,
        );

        await tester.pumpWidget(
          makeTestableWidget(const WasteSummaryCards(stats: emptyStats)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đã dùng'), findsOneWidget);
        expect(find.text('Đã vứt'), findsOneWidget);
        expect(find.text('Lãng phí'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
      },
    );

    testWidgets('renders accurate counts and percentage when data exists', (
      tester,
    ) async {
      const stats = WasteStatistics(
        monthly: [],
        totalConsumed: 15,
        totalDiscarded: 5,
        discardedAfterExpiry: 3,
        topWasted: [],
        wasteRatePercent: 25.0,
      );

      await tester.pumpWidget(
        makeTestableWidget(const WasteSummaryCards(stats: stats)),
      );
      await tester.pumpAndSettle();

      expect(find.text('15'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.textContaining('3 lô bị vứt do quá hạn'), findsOneWidget);
    });
  });

  group('WasteStatisticsPage Widget Tests', () {
    testWidgets('renders page with loaded data without bar chart', (
      tester,
    ) async {
      const stats = WasteStatistics(
        monthly: [],
        totalConsumed: 69,
        totalDiscarded: 12,
        discardedAfterExpiry: 5,
        topWasted: [
          TopWastedFood(
            groupKey: 'apple',
            name: 'Táo Envy',
            categoryId: 'fruit',
            count: 6,
            percentOfDiscarded: 50.0,
          ),
        ],
        wasteRatePercent: 14.8,
      );

      final now = DateTime.now();
      final defaultRange = DateRangeParam(
        startDate: now.subtract(const Duration(days: 29)),
        endDate: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wasteStatisticsProvider(
              defaultRange,
            ).overrideWith((ref) => Future.value(stats)),
          ],
          child: makeTestableWidget(const WasteStatisticsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thống kê lãng phí'), findsOneWidget);
      expect(find.text('69'), findsOneWidget);
      expect(find.text('14.8%'), findsNWidgets(2));
      expect(find.text('Táo Envy'), findsOneWidget);
      // Bar chart is removed, Pie chart is present
      expect(find.text('Tiêu thụ theo tháng'), findsNothing);
      expect(find.text('Tỷ lệ tổng quan'), findsOneWidget);
      expect(find.text('Hay bị vứt nhất'), findsOneWidget);
    });
  });
}
