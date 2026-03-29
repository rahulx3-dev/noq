import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/themes/student_theme.dart';

class LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const LogoutDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: StudentTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: StudentTheme.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: StudentTheme.textSecondary,
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon from Stitch
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: StudentTheme.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: StudentTheme.primaryOrange,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Log Out?',
              style: GoogleFonts.splineSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A), // Explicitly dark
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle
            Text(
              'Are you sure you want to log out of your account?',
              textAlign: TextAlign.center,
              style: GoogleFonts.splineSans(
                fontSize: 14,
                color: const Color(0xFF6B7280), // Explicitly grey
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: StudentTheme.background,
                        foregroundColor: StudentTheme.textTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.splineSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StudentTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 10,
                        shadowColor: StudentTheme.primaryOrange.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        'Logout',
                        style: GoogleFonts.splineSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
