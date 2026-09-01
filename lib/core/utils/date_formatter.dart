import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

enum ExpiryStatus { fresh, expiringSoon, expired }

class DateFormatter {
  DateFormatter._();

  /// Format DateTime to standard date string (defaults to AppConstants.defaultDateFormat: 'dd/MM/yyyy')
  static String formatDate(DateTime date, {String? pattern}) {
    final formatPattern = pattern ?? AppConstants.defaultDateFormat;
    return DateFormat(formatPattern).format(date);
  }

  /// Format DateTime to standard date and time string ('dd/MM/yyyy HH:mm')
  static String formatDateTime(DateTime date) {
    return DateFormat('${AppConstants.defaultDateFormat} HH:mm').format(date);
  }

  /// Calculate the difference in calendar days until expiry date
  /// Returns negative if expired, 0 if expires today, positive if remaining days
  static int getDaysUntilExpiry(DateTime expiryDate, [DateTime? currentDate]) {
    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

    return target.difference(today).inDays;
  }

  /// Categorize food expiry status according to configurable warningThresholdDays
  static ExpiryStatus getExpiryStatus(
    DateTime expiryDate, {
    int warningThresholdDays = 3,
    DateTime? currentDate,
  }) {
    final days = getDaysUntilExpiry(expiryDate, currentDate);
    if (days < 0) {
      return ExpiryStatus.expired;
    }
    if (days <= warningThresholdDays) {
      return ExpiryStatus.expiringSoon;
    }
    return ExpiryStatus.fresh;
  }

  /// Human-readable relative Vietnamese expiry text
  static String formatExpiryRelative(
    DateTime expiryDate, [
    DateTime? currentDate,
  ]) {
    final days = getDaysUntilExpiry(expiryDate, currentDate);

    if (days < 0) {
      final absDays = days.abs();
      return absDays == 1 ? 'Hết hạn hôm qua' : 'Hết hạn $absDays ngày trước';
    }
    if (days == 0) {
      return 'Hết hạn hôm nay';
    }
    if (days == 1) {
      return 'Hết hạn ngày mai';
    }
    if (days < 7) {
      return 'Còn $days ngày';
    }
    if (days < 30) {
      final weeks = (days / 7).floor();
      return 'Còn $weeks tuần';
    }
    final months = (days / 30).floor();
    return 'Còn $months tháng';
  }
}
