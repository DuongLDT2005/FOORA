import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/statistics/domain/entities/stats_period.dart';

void main() {
  group('StatsPeriod', () {
    test('resolves calendar days to Vietnam-time UTC boundaries', () {
      final period = StatsPeriod.fromCalendarDays(
        startDay: DateTime(2026, 10, 1),
        endDay: DateTime(2026, 10, 31),
      );

      // 00:00 on Oct 1 in Vietnam = 17:00 UTC on Sep 30.
      expect(period.startUtc, DateTime.utc(2026, 9, 30, 17));
      // 23:59:59.999 on Oct 31 in Vietnam = 16:59:59.999 UTC on Oct 31.
      expect(period.endUtc, DateTime.utc(2026, 10, 31, 16, 59, 59, 999));
    });

    test('ignores the time of day of the inputs', () {
      final a = StatsPeriod.fromCalendarDays(
        startDay: DateTime(2026, 10, 1, 23, 45),
        endDay: DateTime(2026, 10, 2, 8),
      );
      final b = StatsPeriod.fromCalendarDays(
        startDay: DateTime(2026, 10, 1),
        endDay: DateTime(2026, 10, 2),
      );
      expect(a.startUtc, b.startUtc);
      expect(a.endUtc, b.endUtc);
    });

    test('todayVn rolls over at midnight Vietnam time', () {
      // 16:59 UTC = 23:59 in Vietnam, still Oct 20.
      expect(
        StatsPeriod.todayVn(nowUtc: DateTime.utc(2026, 10, 20, 16, 59)),
        DateTime(2026, 10, 20),
      );
      // 17:00 UTC = 00:00 Oct 21 in Vietnam.
      expect(
        StatsPeriod.todayVn(nowUtc: DateTime.utc(2026, 10, 20, 17)),
        DateTime(2026, 10, 21),
      );
    });
  });
}
