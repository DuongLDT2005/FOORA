import 'package:meta/meta.dart';

/// Units used by shopping items: the item form units plus a few that people
/// often say aloud (PLAN_01 §5.4).
const List<String> shoppingUnits = [
  'quả',
  'hộp',
  'kg',
  'g',
  'miếng',
  'lon',
  'chai',
  'gói',
  'cây',
  'túi',
  'lốc',
  'vỉ',
  'bó',
  'lạng',
  'lít',
  'ml',
];

/// One draft line recognised from speech. [unit] is null when the speaker
/// did not say one; the caller fills in the food's default unit.
@immutable
class VoiceShoppingLine {
  final String name;
  final double quantity;
  final String? unit;

  const VoiceShoppingLine({
    required this.name,
    required this.quantity,
    this.unit,
  });

  @override
  bool operator ==(Object other) =>
      other is VoiceShoppingLine &&
      other.name == name &&
      other.quantity == quantity &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(name, quantity, unit);

  @override
  String toString() => 'VoiceShoppingLine($quantity ${unit ?? '-'} $name)';
}

/// Rule-based parser turning "mua 2 hộp sữa, 1 kg thịt heo và 6 quả trứng"
/// into draft lines. The result is always shown for confirmation before it is
/// saved, so it never needs to be perfect.
class ParseVoiceShoppingTextUseCase {
  const ParseVoiceShoppingTextUseCase();

  static const Map<String, double> _numberWords = {
    'một': 1,
    'hai': 2,
    'ba': 3,
    'bốn': 4,
    'năm': 5,
    'sáu': 6,
    'bảy': 7,
    'tám': 8,
    'chín': 9,
    'mười': 10,
    'nửa': 0.5,
  };

  static const List<String> _prefixes = ['nhớ mua', 'mua', 'thêm', 'cần'];

  /// Commas and dots between digits are decimal separators, not breaks.
  static final RegExp _separator = RegExp(
    r'[,.](?!\d)|(?<!\d)[,.]|;|\s+và\s+|\s+với\s+',
  );

  static final RegExp _line = () {
    // Longer units first so "gói" is not read as "g".
    final units = [...shoppingUnits]
      ..sort((a, b) => b.length.compareTo(a.length));
    final numbers = _numberWords.keys.join('|');
    return RegExp(
      '^(\\d+(?:[.,]\\d+)?|$numbers)\\s*(${units.join('|')})?\\s+(.+)\$',
    );
  }();

  List<VoiceShoppingLine> call(String text) {
    final lines = <VoiceShoppingLine>[];
    for (final rawSegment in text.toLowerCase().split(_separator)) {
      final segment = _stripPrefixes(rawSegment.trim());
      if (segment.isEmpty) continue;

      final match = _line.firstMatch(segment);
      if (match == null) {
        lines.add(VoiceShoppingLine(name: _capitalize(segment), quantity: 1));
        continue;
      }

      var quantity = _parseNumber(match.group(1)!);
      var unit = match.group(2);
      final name = match.group(3)!.trim();
      if (unit == 'lạng') {
        // 1 lạng = 100 g, stored in kg.
        quantity = double.parse((quantity * 0.1).toStringAsFixed(3));
        unit = 'kg';
      }
      lines.add(
        VoiceShoppingLine(
          name: _capitalize(name),
          quantity: quantity,
          unit: unit,
        ),
      );
    }
    return lines;
  }

  static String _stripPrefixes(String segment) {
    var result = segment;
    var changed = true;
    while (changed) {
      changed = false;
      for (final prefix in _prefixes) {
        if (result == prefix) return '';
        if (result.startsWith('$prefix ')) {
          result = result.substring(prefix.length).trim();
          changed = true;
        }
      }
    }
    return result;
  }

  static double _parseNumber(String token) {
    return _numberWords[token] ?? double.parse(token.replaceAll(',', '.'));
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
