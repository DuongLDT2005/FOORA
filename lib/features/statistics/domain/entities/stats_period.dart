import 'package:meta/meta.dart';

/// A statistics period made of whole calendar days in Vietnam time
/// (UTC+7, no DST), resolved to the exact UTC instants used for querying.
///
/// Using a fixed offset instead of the device time zone keeps the numbers
/// identical on every device (emulators commonly run in UTC).
@immutable
class StatsPeriod {
  /// Builds the period from `[startDay 00:00, endDay 23:59:59.999]` in
  /// Vietnam time. Only the year/month/day parts of the inputs are used.
  StatsPeriod.fromCalendarDays({
    required DateTime startDay,
    required DateTime endDay,
  }) : startUtc = DateTime.utc(
         startDay.year,
         startDay.month,
         startDay.day,
       ).subtract(vnOffset),
       endUtc = DateTime.utc(
         endDay.year,
         endDay.month,
         endDay.day + 1,
       ).subtract(vnOffset).subtract(const Duration(milliseconds: 1));

  static const Duration vnOffset = Duration(hours: 7);

  /// Inclusive lower bound (UTC).
  final DateTime startUtc;

  /// Inclusive upper bound (UTC).
  final DateTime endUtc;

  /// Today's calendar date in Vietnam, as a date-only value.
  static DateTime todayVn({DateTime? nowUtc}) {
    final nowVn = (nowUtc ?? DateTime.now()).toUtc().add(vnOffset);
    return DateTime(nowVn.year, nowVn.month, nowVn.day);
  }
}
