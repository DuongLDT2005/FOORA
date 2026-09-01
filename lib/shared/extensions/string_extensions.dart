extension StringExtensions on String {
  /// Capitalize the first letter of the string (e.g. 'rau củ' -> 'Rau củ')
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalize every word in the string (e.g. 'thịt bò tươi' -> 'Thịt Bò Tươi')
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isNotEmpty ? word.capitalize() : '')
        .join(' ');
  }

  /// Obscure email for privacy (e.g. 'duongldt2005@gmail.com' -> 'd***5@gmail.com')
  String obscureEmail() {
    if (!contains('@')) return this;
    final parts = split('@');
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '${name[0]}*@$domain';
    }
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  /// Basic email format check
  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(trim());
  }
}
