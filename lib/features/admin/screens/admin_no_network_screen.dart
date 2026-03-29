import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/themes/admin_theme.dart';

class AdminNoNetworkScreen extends StatefulWidget {
  const AdminNoNetworkScreen({super.key});

  @override
  State<AdminNoNetworkScreen> createState() => _AdminNoNetworkScreenState();
}

class _AdminNoNetworkScreenState extends State<AdminNoNetworkScreen> {
  bool _isChecking = false;

  Future<void> _checkNetwork() async {
    setState(() => _isChecking = true);
    
    // Simulate a minimum delay for the animation
    await Future.delayed(const Duration(milliseconds: 1000));
    
    bool hasNetwork = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasNetwork = true;
      }
    } on SocketException catch (_) {
      hasNetwork = false;
    }

    if (!mounted) return;

    setState(() => _isChecking = false);

    if (hasNetwork) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/admin/dashboard');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Still offline. Please check your management connection.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AdminTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom Wi-Fi Off Icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AdminTheme.error.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  margin: const EdgeInsets.only(bottom: 28),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(64, 64),
                      painter: _WifiOffPainter(color: AdminTheme.textPrimary),
                    ),
                  ),
                ),

                // Title
                Text(
                  'Admin Offline',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AdminTheme.textPrimary,
                    letterSpacing: -0.6,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  'Unable to sync with management services. Connect to manage menus, orders, and reports.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AdminTheme.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // Context Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AdminTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AdminTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.cloud_off_rounded,
                          color: AdminTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cloud Services Unavailable',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AdminTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Please verify your internet connection to continue administrative tasks.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AdminTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Try Again Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkNetwork,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AdminTheme.primary.withValues(alpha: 0.7),
                      disabledForegroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AdminTheme.primary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.refresh_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'REFRESH DASHBOARD',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WifiOffPainter extends CustomPainter {
  final Color color;
  _WifiOffPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paintObj = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.5;

    // Outer arc — faded
    paintObj.color = color.withValues(alpha: 0.18);
    final path1 = Path()
      ..moveTo(4, 28)
      ..quadraticBezierTo(32, 4, 60, 28);
    canvas.drawPath(path1, paintObj);

    // Mid arc
    paintObj.color = color.withValues(alpha: 0.45);
    final path2 = Path()
      ..moveTo(12, 37)
      ..quadraticBezierTo(32, 16, 52, 37);
    canvas.drawPath(path2, paintObj);

    // Inner arc — solid
    paintObj.color = color;
    final path3 = Path()
      ..moveTo(21, 46)
      ..quadraticBezierTo(32, 30, 43, 46);
    canvas.drawPath(path3, paintObj);

    // Dot
    paintObj.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(32, 56), 4, paintObj);

    // Red diagonal cut line
    paintObj.style = PaintingStyle.stroke;
    paintObj.strokeWidth = 5.0;
    paintObj.color = const Color(0xFFD9372A);
    canvas.drawLine(const Offset(6, 6), const Offset(58, 58), paintObj);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
