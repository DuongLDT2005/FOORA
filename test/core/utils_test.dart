import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/utils/currency_formatter.dart';
import 'package:foora/core/utils/date_formatter.dart';
import 'package:foora/core/utils/input_validators.dart';

void main() {
  group('DateFormatter Tests', () {
    final now = DateTime(2026, 9, 1);

    test('formatDate formats using default pattern', () {
      final date = DateTime(2026, 9, 15);
      expect(DateFormatter.formatDate(date), '15/09/2026');
    });

    test('getDaysUntilExpiry calculates remaining days correctly', () {
      final futureDate = DateTime(2026, 9, 4);
      expect(DateFormatter.getDaysUntilExpiry(futureDate, now), 3);

      final expiredDate = DateTime(2026, 8, 30);
      expect(DateFormatter.getDaysUntilExpiry(expiredDate, now), -2);
    });

    test('getExpiryStatus respects warningThresholdDays', () {
      final freshDate = DateTime(2026, 9, 10);
      expect(
        DateFormatter.getExpiryStatus(
          freshDate,
          warningThresholdDays: 3,
          currentDate: now,
        ),
        ExpiryStatus.fresh,
      );

      final expiringSoonDate = DateTime(2026, 9, 3);
      expect(
        DateFormatter.getExpiryStatus(
          expiringSoonDate,
          warningThresholdDays: 3,
          currentDate: now,
        ),
        ExpiryStatus.expiringSoon,
      );

      final expiredDate = DateTime(2026, 8, 31);
      expect(
        DateFormatter.getExpiryStatus(
          expiredDate,
          warningThresholdDays: 3,
          currentDate: now,
        ),
        ExpiryStatus.expired,
      );
    });

    test('formatExpiryRelative returns accurate Vietnamese labels', () {
      expect(
        DateFormatter.formatExpiryRelative(DateTime(2026, 9, 1), now),
        'Hết hạn hôm nay',
      );
      expect(
        DateFormatter.formatExpiryRelative(DateTime(2026, 9, 2), now),
        'Hết hạn ngày mai',
      );
      expect(
        DateFormatter.formatExpiryRelative(DateTime(2026, 8, 31), now),
        'Hết hạn hôm qua',
      );
      expect(
        DateFormatter.formatExpiryRelative(DateTime(2026, 9, 4), now),
        'Còn 3 ngày',
      );
    });
  });

  group('CurrencyFormatter Tests', () {
    test('formatVND formats amount and handles zero', () {
      expect(CurrencyFormatter.formatVND(0), 'Miễn phí');
      expect(
        CurrencyFormatter.formatVND(0, showFreeText: false).contains('0'),
        isTrue,
      );
      expect(CurrencyFormatter.formatVND(150000).contains('150.000'), isTrue);
    });
  });

  group('InputValidators Tests', () {
    test('validateEmail checks standard email syntax', () {
      expect(InputValidators.validateEmail(''), isNotNull);
      expect(InputValidators.validateEmail('invalid-email'), isNotNull);
      expect(InputValidators.validateEmail('user@foora.vn'), isNull);
    });

    test('validatePassword enforces minimum length', () {
      expect(InputValidators.validatePassword('123'), isNotNull);
      expect(InputValidators.validatePassword('123456'), isNull);
    });

    test('validateRequired catches empty inputs', () {
      expect(InputValidators.validateRequired('', 'Tên thực phẩm'), isNotNull);
      expect(
        InputValidators.validateRequired('Thịt bò', 'Tên thực phẩm'),
        isNull,
      );
    });

    test('validatePositiveNumber enforces > 0', () {
      expect(
        InputValidators.validatePositiveNumber('0', 'Số lượng'),
        isNotNull,
      );
      expect(
        InputValidators.validatePositiveNumber('-5', 'Số lượng'),
        isNotNull,
      );
      expect(InputValidators.validatePositiveNumber('2.5', 'Số lượng'), isNull);
    });
  });
}
