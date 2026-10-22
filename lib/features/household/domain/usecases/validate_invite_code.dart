/// Normalizes and validates a household invite code typed by the user.
///
/// Mirrors `functions/src/household/services/invite_code.ts`: 6 characters
/// from an alphabet without look-alikes (0/O, 1/I/L). Client-side checks are
/// for UX only; the backend validates again.
class ValidateInviteCodeUseCase {
  static const int codeLength = 6;
  static final RegExp _pattern = RegExp(r'^[A-HJKMNP-Z2-9]{6}$');

  const ValidateInviteCodeUseCase();

  /// Upper-cases the input and removes whitespace and dashes.
  String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  /// Returns the normalized code, or `null` when it cannot be a valid code.
  String? call(String raw) {
    final code = normalize(raw);
    return _pattern.hasMatch(code) ? code : null;
  }
}
