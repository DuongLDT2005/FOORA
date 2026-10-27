String? suggestAiCategoryId(String name) {
  var text = name.toLowerCase().trim();
  const marks = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final entry in marks.entries) {
    for (final mark in entry.value.split('')) {
      text = text.replaceAll(mark, entry.key);
    }
  }
  text = text
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (RegExp(
    r'^(rau|cai|bap cai|khoai|ca rot|ca chua|ca tim|nam|hanh|su hao|bi do)\b',
  ).hasMatch(text)) {
    return 'vegetables';
  }
  if (RegExp(
    r'^(cua|tom|ca|muc|oc|so|ngao|hau|ghe|hai san)\b',
  ).hasMatch(text)) {
    return 'seafood';
  }
  if (RegExp(r'^(thit|ga|vit|heo|lon|bo vien)\b').hasMatch(text)) {
    return 'meat';
  }
  if (RegExp(r'^(trung|sua|pho mai|bot sua|sua chua)\b').hasMatch(text)) {
    return 'dairy_eggs';
  }
  if (RegExp(r'^(gao|bun|mi|pho|banh mi|yen mach)\b').hasMatch(text)) {
    return 'grains_staples';
  }
  if (RegExp(r'^(tao|chuoi|cam|quyt|xoai|dua hau|nho|le)\b').hasMatch(text)) {
    return 'fruits';
  }
  return null;
}
