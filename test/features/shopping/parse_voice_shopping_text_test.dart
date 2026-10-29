import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/shopping/domain/usecases/parse_voice_shopping_text.dart';

void main() {
  const parse = ParseVoiceShoppingTextUseCase();

  test('splits several items and strips the "mua" prefix', () {
    expect(parse('Mua 2 hộp sữa, 1 kg thịt heo và 6 quả trứng'), const [
      VoiceShoppingLine(name: 'Sữa', quantity: 2, unit: 'hộp'),
      VoiceShoppingLine(name: 'Thịt heo', quantity: 1, unit: 'kg'),
      VoiceShoppingLine(name: 'Trứng', quantity: 6, unit: 'quả'),
    ]);
  });

  test('reads number words and "nửa"', () {
    expect(parse('nhớ mua ba bó rau muống; nửa kg tôm'), const [
      VoiceShoppingLine(name: 'Rau muống', quantity: 3, unit: 'bó'),
      VoiceShoppingLine(name: 'Tôm', quantity: 0.5, unit: 'kg'),
    ]);
  });

  test('converts "lạng" to kg', () {
    expect(parse('3 lạng thịt bò'), const [
      VoiceShoppingLine(name: 'Thịt bò', quantity: 0.3, unit: 'kg'),
    ]);
  });

  test('keeps decimal numbers with a comma or a dot', () {
    expect(parse('1,5 kg cam. 2.5 lít sữa'), const [
      VoiceShoppingLine(name: 'Cam', quantity: 1.5, unit: 'kg'),
      VoiceShoppingLine(name: 'Sữa', quantity: 2.5, unit: 'lít'),
    ]);
  });

  test('leaves the unit empty when none is said', () {
    expect(parse('2 gà'), const [VoiceShoppingLine(name: 'Gà', quantity: 2)]);
    expect(parse('5 gói mì'), const [
      VoiceShoppingLine(name: 'Mì', quantity: 5, unit: 'gói'),
    ]);
  });

  test('falls back to quantity 1 and the whole phrase', () {
    expect(parse('thêm nước mắm'), const [
      VoiceShoppingLine(name: 'Nước mắm', quantity: 1),
    ]);
  });

  test('returns nothing for empty input', () {
    expect(parse(''), isEmpty);
    expect(parse('  ,  mua  '), isEmpty);
  });
}
