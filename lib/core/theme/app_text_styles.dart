import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static String get fontFamilySans => GoogleFonts.inter().fontFamily ?? 'Inter';
  static String get fontFamilyHeadline =>
      GoogleFonts.lexend().fontFamily ?? 'Lexend';

  // ===========================================================================
  // 🏷️ HEADLINES & TITLES (Font: Lexend - Bold, specialized for headings)
  // ===========================================================================

  /// Maximum display size (Tailwind text-4xl -> 40px)
  static TextStyle get displayLarge => GoogleFonts.lexend(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// Large hero title (Tailwind text-3xl -> 34px)
  static TextStyle get headlineLarge => GoogleFonts.lexend(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// Main screen header (Tailwind text-2xl -> 28px)
  static TextStyle get headlineMedium => GoogleFonts.lexend(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  /// Secondary screen header, Dialog title (Tailwind text-xl -> 24px)
  static TextStyle get headlineSmall =>
      GoogleFonts.lexend(fontSize: 24, fontWeight: FontWeight.w700);

  /// Section title, Card Header (Tailwind text-lg -> 20px)
  static TextStyle get titleLarge =>
      GoogleFonts.lexend(fontSize: 20, fontWeight: FontWeight.w700);

  /// Medium title (Tailwind text-base -> 18px)
  static TextStyle get titleMedium =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600);

  /// Small title (Tailwind text-sm -> 16px)
  static TextStyle get titleSmall =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);

  /// Subtitle, Segmented tab text (Tailwind text-xs -> 15px Lexend Bold)
  static TextStyle get tabLabel =>
      GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w700);

  // ===========================================================================
  // 📝 BODY & CONTENT (Font: Inter - Clean, legible, standard iOS/Android)
  // ===========================================================================

  /// Primary body text (Tailwind text-base -> 17px)
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  /// Input text, Placeholder, Info list (Tailwind text-xs -> 15px)
  static TextStyle get bodyMedium =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500);

  /// Secondary description, Error banner message (Tailwind text-[10px] -> 13px)
  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4);

  /// Extra small caption, Terms of service, Disclaimer (Tailwind text-[9px] -> 12px)
  static TextStyle get caption =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);

  // ===========================================================================
  // 🔘 BUTTONS & LABELS (Font: Inter - Bold weight, optimized for touch actions)
  // ===========================================================================

  /// Large button (Tailwind text-sm -> 16px, fontWeight: 700)
  static TextStyle get labelLarge =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700);

  /// Convenient alias for primary button
  static TextStyle get buttonPrimary => labelLarge;

  /// Text link, Forgot password, Secondary button (Tailwind text-xs -> 14px)
  static TextStyle get labelMedium =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700);

  /// Uppercase Input Field Label (FULL NAME, EMAIL ADDRESS) (Tailwind text-[10px] -> 13px bold)
  static TextStyle get inputLabel => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  /// Sub-labels, Badge text, Small tags (Tailwind text-[9px] -> 12px)
  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}
