import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StaffTheme {
  // Brand Colors (Stitch)
  static const Color primary = Color(0xFF1A2E05);
  static const Color secondary = Color(0xFF9BEF6B);
  static const Color accent = Color(0xFFE9F0E6);

  // Legacy mappings for backwards compatibility while we refactor
  static const Color primaryOrange = secondary; // Replace usage over time

  // Background & Surface
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color surfaceVariant = Color(0xFFF3F4F6);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A2E05);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Status Colors (from Stitch Tailwind classes)
  static const Color statusPending = Color(0xFF111827); // Gray-900
  static const Color statusReady = Color(0xFF16A34A);   // Green-600
  static const Color statusServed = Color(0xFF16A34A);  // Green-600
  static const Color statusSkipped = Color(0xFFEF4444); // Red-500
  static const Color statusPartial = Color(0xFFEAB308); // Yellow-500
  static const Color statusScheduled = Color(0xFF6B7280); // Gray-500

  static ThemeData theme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme).copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: textPrimary,
      ),
    );
  }
}
