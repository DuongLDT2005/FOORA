import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  /// Format amount in Vietnamese Dong (e.g. '150.000 ₫' or 'Miễn phí' for 0)
  static String formatVND(num amount, {bool showFreeText = true}) {
    if (amount == 0 && showFreeText) {
      return 'Miễn phí';
    }
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount).trim();
  }

  /// Format amount with custom currency code and locale
  static String formatCurrency(
    num amount, {
    String currency = 'VND',
    String locale = 'vi_VN',
    int decimalDigits = 0,
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: currency == 'VND' ? '₫' : currency,
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount).trim();
  }
}
