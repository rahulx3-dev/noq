import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false, // Critical: No Material 3
      primarySwatch: Colors.orange,
      scaffoldBackgroundColor: const Color(0xFFFDF8F5),
      textTheme: GoogleFonts.splineSansTextTheme(),
    );
  }
}
