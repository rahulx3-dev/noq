import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app/themes/student_theme.dart';

/// A full-screen bottom sheet that displays a QR code for a given token.
/// The QR payload is a JSON string of { checkoutGroupId, tokenNumber }.
class StudentQrSheet extends StatelessWidget {
  final String checkoutGroupId;
  final String tokenNumber;

  const StudentQrSheet({
    super.key,
    required this.checkoutGroupId,
    required this.tokenNumber,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({
      'checkoutGroupId': checkoutGroupId,
      'tokenNumber': tokenNumber,
    });

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              // Drag handle
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                'PICKUP QR',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: StudentTheme.textSecondary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              // Token number
              Text(
                '#$tokenNumber',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: StudentTheme.primary,
                  letterSpacing: -3,
                ),
              ),
              const SizedBox(height: 32),
              // QR Code
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: StudentTheme.primary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: StudentTheme.primary,
                  ),
                  gapless: true,
                ),
              ),
              const SizedBox(height: 40),
              // Helper text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: StudentTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: StudentTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Show at pickup counter',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: StudentTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
