class InputValidators {
  InputValidators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ email của bạn.';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Định dạng email không hợp lệ (ví dụ: user@example.com).';
    }
    return null;
  }

  /// Validate password length
  static String? validatePassword(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu.';
    }
    if (value.length < minLength) {
      return 'Mật khẩu phải chứa ít nhất $minLength ký tự.';
    }
    return null;
  }

  /// Validate confirm password matching
  static String? validateConfirmPassword(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Vui lòng xác nhận mật khẩu.';
    }
    if (password != confirmPassword) {
      return 'Mật khẩu xác nhận không khớp.';
    }
    return null;
  }

  /// Validate required non-empty field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName của bạn.';
    }
    return null;
  }

  /// Validate positive number (greater than 0)
  static String? validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName.';
    }
    final number = num.tryParse(value.trim().replaceAll(',', '.'));
    if (number == null || number <= 0) {
      return '$fieldName phải là số dương lớn hơn 0.';
    }
    return null;
  }

  /// Validate non-negative number (greater than or equal to 0)
  static String? validateNonNegativeNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName.';
    }
    final number = num.tryParse(value.trim().replaceAll(',', '.'));
    if (number == null || number < 0) {
      return '$fieldName phải lớn hơn hoặc bằng 0.';
    }
    return null;
  }
}
