/// Utility for Vietnamese string normalization and fuzzy text matching
class StringUtils {
  StringUtils._();

  static const _vietnameseMap = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'A': 'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬ',
    'd': 'đ',
    'D': 'Đ',
    'e': 'éèẻẽẹêếềểễệ',
    'E': 'ÉÈẺẼẸÊẾỀỂỄỆ',
    'i': 'íìỉĩị',
    'I': 'ÍÌỈĨỊ',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'O': 'ÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢ',
    'u': 'úùủũụưứừửữự',
    'U': 'ÚÙỦŨỤƯỨỪỬỮỰ',
    'y': 'ýỳỷỹỵ',
    'Y': 'ÝỲỶỸỴ',
  };

  /// Normalizes Vietnamese and arbitrary text to lowercase unaccented string.
  /// Example: "Rau muống" -> "rau muong", "Thịt bò" -> "thit bo"
  static String normalize(String text) {
    if (text.isEmpty) return '';

    String result = text;
    _vietnameseMap.forEach((nonAccent, accents) {
      for (int i = 0; i < accents.length; i++) {
        result = result.replaceAll(accents[i], nonAccent);
      }
    });

    return result
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Checks if target string contains query string in a normalized manner
  static bool containsNormalized(String source, String query) {
    final normSource = normalize(source);
    final normQuery = normalize(query);
    return normSource.contains(normQuery);
  }
}
