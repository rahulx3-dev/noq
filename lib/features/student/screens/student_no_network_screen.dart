import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentNoNetworkScreen extends StatefulWidget {
  const StudentNoNetworkScreen({super.key});

  @override
  State<StudentNoNetworkScreen> createState() => _StudentNoNetworkScreenState();
}

class _StudentNoNetworkScreenState extends State<StudentNoNetworkScreen>
    with SingleTickerProviderStateMixin {
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
        context.go('/student/dashboard');
      }
    } else {
      // Show brief error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Still offline. Please check your connection.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFFD9372A),
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
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom Wi-Fi Off SVG Icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9372A).withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  margin: const EdgeInsets.only(bottom: 28),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(64, 64),
                      painter: _WifiOffPainter(),
                    ),
                  ),
                ),

                // Title
                Text(
                  'No Internet Connection',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF302F2C),
                    letterSpacing: -0.6,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  'You\'re offline. Connect to browse today\'s menu and place orders.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9CA3AF),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 32),

                // Context Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF302F2C),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Can\'t load today\'s menu',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Your active tokens are saved locally and still visible in My Tokens',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.38),
                                height: 1.45,
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
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkNetwork,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD9372A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD9372A).withValues(alpha: 0.7),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.refresh_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Try Again',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // View Offline Tokens Button
                TextButton(
                    onPressed: () {
                      context.push('/student/token');
                    },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFBBB0A4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'View My Active Tokens →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
  @override
  void paint(Canvas canvas, Size size) {
    final paintObj = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.5;

    final color = const Color(0xFF302F2C);

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
