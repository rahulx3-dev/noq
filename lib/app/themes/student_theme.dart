import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentTheme {
  // Brand Colors
  static const Color primary = Color(0xFF302F2C);
  static const Color accent = Color(0xFFFF4B3A);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF4F5F7);
  static const Color surfaceVariant = Color(0xFFF9FAFB);
  static const Color cardBgDark = Color(0xFF302F2C);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Status Colors
  static const Color statusGreen = Color(0xFF10B981);
  static const Color statusAmber = Color(0xFFF59E0B);
  static const Color statusBlue = Color(0xFF3B82F6);
  static const Color statusRed = Color(0xFFEF4444);

  // Misc
  static const Color border = Color(0xFFF3F4F6);

  // DEPRECATED ALIASES FOR MIGRATION
  static const Color primaryOrange = Color(0xFF302F2C); // primary
  static const Color accentOrange = Color(0xFFFF4B3A); // accent
  static const Color secondaryPurple = Color(0xFFFF4B3A); // accent
  static const Color textOnLight = Color(0xFF1A1A1A); // textPrimary
  static const Color statusGreenText = Color(0xFF10B981); // statusGreen
  static const Color statusRedText = Color(0xFFEF4444); // statusRed
  static const Color tagLunch = Color(0xFFF9FAFB); // surfaceVariant
  static const Color tagLunchText = Color(0xFF302F2C); // primary
  static const Color tagDinner = Color(0xFFF9FAFB); // surfaceVariant
  static const Color tagDinnerText = Color(0xFF302F2C); // primary

  static ThemeData theme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: background,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: primary),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.plusJakartaSans(
              color: textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            displayMedium: GoogleFonts.plusJakartaSans(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            displaySmall: GoogleFonts.plusJakartaSans(
              color: textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            bodyLarge: GoogleFonts.plusJakartaSans(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            bodyMedium: GoogleFonts.plusJakartaSans(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            bodySmall: GoogleFonts.plusJakartaSans(
              color: textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
      cardTheme: CardThemeData(
        color: cardBgDark,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.plusJakartaSans(color: textTertiary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
