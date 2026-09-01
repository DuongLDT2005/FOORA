import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static String get fontFamilySans => GoogleFonts.inter().fontFamily ?? 'Inter';
  static String get fontFamilyHeadline =>
      GoogleFonts.lexend().fontFamily ?? 'Lexend';

  // Headlines (Sử dụng Lexend, béo, chuyên dành cho Tiêu đề)
  static TextStyle get displayLarge => GoogleFonts.lexend(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  static TextStyle get headlineLarge =>
      GoogleFonts.lexend(fontSize: 32, fontWeight: FontWeight.w700);

  static TextStyle get headlineMedium =>
      GoogleFonts.lexend(fontSize: 28, fontWeight: FontWeight.w700);

  static TextStyle get headlineSmall =>
      GoogleFonts.lexend(fontSize: 24, fontWeight: FontWeight.w700);

  static TextStyle get titleLarge =>
      GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.w600);

  // Body & Content (Sử dụng Inter, nét thanh, dễ đọc)
  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
  );

  static TextStyle get titleSmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // Labels (Các nhãn nhỏ, tag, chữ ở nút bấm...)
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
}
