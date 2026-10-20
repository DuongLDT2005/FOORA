import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/statistics/domain/entities/waste_statistics.dart';
import 'package:foora/features/statistics/presentation/pages/waste_statistics_page.dart';
import 'package:foora/features/statistics/presentation/providers/waste_statistics_provider.dart';
import 'package:foora/features/statistics/presentation/widgets/period_selector.dart';
import 'package:foora/features/statistics/presentation/widgets/waste_summary_cards.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('PeriodSelector Widget Tests', () {
    testWidgets('renders all period options and calls onChanged when clicked', (
      tester,
    ) async {
      int selected = 6;
      await tester.pumpWidget(
        makeTestableWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return PeriodSelector(
                selectedMonths: selected,
                onChanged: (val) {
                  setState(() => selected = val);
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 tháng'), findsOneWidget);
      expect(find.text('6 tháng'), findsOneWidget);
      expect(find.text('12 tháng'), findsOneWidget);

      await tester.tap(find.text('12 tháng'));
      await tester.pumpAndSettle();

      expect(selected, 12);
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
      expect(find.text('3 lô quá hạn'), findsOneWidget);
    });
  });

  group('WasteStatisticsPage Widget Tests', () {
    testWidgets('renders page with loaded data', (tester) async {
      const stats = WasteStatistics(
        monthly: [
          MonthlyWaste(year: 2026, month: 5, consumed: 10, discarded: 2),
          MonthlyWaste(year: 2026, month: 6, consumed: 8, discarded: 1),
          MonthlyWaste(year: 2026, month: 7, consumed: 16, discarded: 3),
          MonthlyWaste(year: 2026, month: 8, consumed: 9, discarded: 0),
          MonthlyWaste(year: 2026, month: 9, consumed: 15, discarded: 4),
          MonthlyWaste(year: 2026, month: 10, consumed: 11, discarded: 2),
        ],
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wasteStatisticsProvider(
              6,
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
      expect(find.text('Tiêu thụ theo tháng'), findsOneWidget);
      expect(find.text('Hay bị vứt nhất'), findsOneWidget);
    });
  });
}
