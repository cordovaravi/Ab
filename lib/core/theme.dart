import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WorldOSTheme {
  static const bg = Color(0xFF06060E);
  static const surface = Color(0xFF0D0D1A);
  static const card = Color(0xFF141428);
  static const cardHover = Color(0xFF1A1A35);
  static const border = Color(0xFF1E1E3A);

  static const cyan = Color(0xFF00E5FF);
  static const amber = Color(0xFFFFB800);
  static const green = Color(0xFF00FF88);
  static const red = Color(0xFFFF2D55);
  static const purple = Color(0xFFA855F7);

  static const textPrimary = Color(0xFFE8E8F0);
  static const textSecondary = Color(0xFF9A9AB0);
  static const textMuted = Color(0xFF6B6B80);

  static TextStyle get heading1 => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.2,
      );

  static TextStyle get heading2 => GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get heading3 => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get body => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.6,
      );

  static TextStyle get bodySmall => GoogleFonts.dmSans(
        fontSize: 12,
        color: textMuted,
      );

  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 10,
        color: textMuted,
        letterSpacing: 0.5,
      );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        color: cyan,
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      );

  static BoxDecoration glowDecoration(Color color) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      );

  static BoxDecoration get inputDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      );

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: cyan,
          secondary: amber,
          surface: surface,
          error: red,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          titleTextStyle: heading3,
          iconTheme: const IconThemeData(color: textPrimary),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
        ),
        cardTheme: CardThemeData(
          color: card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
        ),
      );
}
