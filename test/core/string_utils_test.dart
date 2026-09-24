import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/utils/string_utils.dart';

void main() {
  group('StringUtils Tests', () {
    test(
      'normalize removes Vietnamese diacritics and converts to lower-case',
      () {
        expect(StringUtils.normalize('Rau muống'), 'rau muong');
        expect(StringUtils.normalize('Thịt bò nạc'), 'thit bo nac');
        expect(StringUtils.normalize('Trứng gà tươi'), 'trung ga tuoi');
        expect(StringUtils.normalize('Đậu phụ'), 'dau phu');
        expect(StringUtils.normalize('ỔI RUỘT ĐỎ'), 'oi ruot do');
      },
    );

    test('normalize handles empty and symbols', () {
      expect(StringUtils.normalize(''), '');
      expect(StringUtils.normalize('  Cà chua, quả !  '), 'ca chua qua');
    });

    test('containsNormalized matches accented and unaccented variations', () {
      expect(
        StringUtils.containsNormalized('Thịt ba chỉ heo', 'thit heo'),
        isFalse, // full phrase substring check
      );
      expect(
        StringUtils.containsNormalized('Thịt ba chỉ heo', 'ba chi'),
        isTrue,
      );
      expect(
        StringUtils.containsNormalized('Rau mồng tơi', 'mong toi'),
        isTrue,
      );
      expect(StringUtils.containsNormalized('Cá hồi Nauy', 'ca hoi'), isTrue);
    });
  });
}
