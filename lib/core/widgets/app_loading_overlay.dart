import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppLoadingOverlay extends StatefulWidget {
  const AppLoadingOverlay({super.key});

  @override
  State<AppLoadingOverlay> createState() => _AppLoadingOverlayState();
}

class _AppLoadingOverlayState extends State<AppLoadingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;

  late AnimationController _dotsController;
  
  int _currentCount = 1;
  static const int _maxCount = 24;
  Timer? _countTimer;
  
  bool _isConfirmed = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _borderAnimation = CurvedAnimation(
      parent: _borderController,
      curve: const Cubic(0.4, 0, 0.2, 1), 
    );

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 700), _startLoop);
  }

  void _startLoop() {
    if (!mounted) return;
    setState(() {
      _isConfirmed = false;
      _isResetting = false;
      _currentCount = 1;
    });

    _borderController.forward(from: 0.0);

    final stepMs = (2400 / (_maxCount - 1)).round();
    _countTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentCount++;
      });
      if (_currentCount >= _maxCount) {
        timer.cancel();
        _onConfirmed();
      }
    });
  }

  void _onConfirmed() {
    if (!mounted) return;
    setState(() {
      _isConfirmed = true;
    });

    Future.delayed(const Duration(milliseconds: 900), _doReset);
  }

  void _doReset() {
    if (!mounted) return;
    setState(() {
      _isResetting = true;
      _isConfirmed = false;
    });
    _borderController.reset();

    Future.delayed(const Duration(milliseconds: 450), _startLoop);
  }

  @override
  void dispose() {
    _borderController.dispose();
    _dotsController.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Force full screen by using a Stack that fits the entire screen
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
            color: const Color(0xFF0F0F0F),
          ),

          // Border Overlay (Perimeter of screen)
          AnimatedBuilder(
            animation: _borderAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _FullScreenBorderPainter(
                  progress: _borderAnimation.value,
                  isResetting: _isResetting,
                ),
              );
            },
          ),

          // Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Token Card Wrap
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: 1.0,
                  child: Container(
                    width: 200,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Card Border SVG (Simulated with CustomPaint inside card if desired, 
                        // but HTML shows border draws over card)
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'YOUR TOKEN',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.22),
                                  letterSpacing: 1.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Number
                              Expanded(
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 100),
                                    transitionBuilder: (Widget child, Animation<double> animation) {
                                      return ScaleTransition(
                                        scale: Tween<double>(begin: 1.14, end: 1.0).animate(animation),
                                        child: FadeTransition(opacity: animation, child: child),
                                      );
                                    },
                                    child: AnimatedOpacity(
                                      key: ValueKey(_currentCount),
                                      duration: const Duration(milliseconds: 250),
                                      opacity: _isResetting ? 0.0 : 1.0,
                                      child: Text(
                                        '$_currentCount',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 80,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -5,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Status
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: _isResetting ? 0.0 : 1.0,
                                child: Text(
                                  _isConfirmed ? 'ready to collect!' : 'confirming...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _isConfirmed
                                        ? const Color(0xFF10B981)
                                        : Colors.white.withValues(alpha: 0.28),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              
                              // Icon Slot
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 350),
                                opacity: _isConfirmed ? 1.0 : 0.0,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 350),
                                  scale: _isConfirmed ? 1.0 : 0.5,
                                  curve: Curves.elasticOut,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.10),
                                      ),
                                    ),
                                    child: const _ForkKnifeIcon(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Dots
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => _PulsingDot(
                    controller: _dotsController,
                    index: index,
                  )),
                ),
              ],
            ),
          ),

          // Branding Bottom
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: RichText(
                text: TextSpan(
                  text: 'noq',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  children: [
                    TextSpan(
                      text: '.',
                      style: TextStyle(
                        color: const Color(0xFFD9372A).withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _PulsingDot({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final delay = index * 0.2;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double t = (controller.value - (delay / 1.4)) % 1.0;
        if (t < 0) t += 1.0;

        double scale = 1.0;
        double opacity = 0.15;

        // 0%, 60%, 100% -> opacity 0.15, scale 1
        // 30% -> opacity 1, scale 1.5
        if (t <= 0.6) {
          if (t <= 0.3) {
            final p = t / 0.3;
            scale = 1.0 + (0.5 * p);
            opacity = 0.15 + (0.85 * p);
          } else {
            final p = (t - 0.3) / 0.3;
            scale = 1.5 - (0.5 * p);
            opacity = 1.0 - (0.85 * p);
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 5,
          height: 5,
          transform: Matrix4.identity()..scale(scale),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14 * opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _ForkKnifeIcon extends StatelessWidget {
  const _ForkKnifeIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _ForkKnifePainter(),
      ),
    );
  }
}

class _ForkKnifePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final forkPath = Path()
      ..moveTo(6, 2)
      ..lineTo(6, 6)
      ..arcToPoint(
        const Offset(11, 2),
        radius: const Radius.circular(2.5),
        clockwise: false,
      );
    canvas.drawPath(forkPath, paint);
    canvas.drawLine(const Offset(8.5, 6), const Offset(8.5, 18), paint);
    
    final knifePath = Path()
      ..moveTo(14, 2)
      ..relativeQuadraticBezierTo(-2.5, 2.5, -2.5, 6)
      ..relativeQuadraticBezierTo(2.5, 4, 2.5, 4)
      ..lineTo(14, 18);
    canvas.drawPath(knifePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FullScreenBorderPainter extends CustomPainter {
  final double progress;
  final bool isResetting;

  _FullScreenBorderPainter({
    required this.progress,
    required this.isResetting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isResetting) return;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      const Radius.circular(50.0),
    );

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rect, trackPaint);

    if (progress <= 0) return;

    // Gradient Fill
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final gradient = const LinearGradient(
      colors: [
        Color(0xFFD9372A),
        Color(0xFFF59E0B),
        Color(0xFFE8F5C8),
      ],
      stops: [0.0, 0.4, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    fillPaint.shader = gradient;

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final extractProgress = progress; 
    
    // Spec has a custom timing for the stroke draw
    // 0% -> 1000, 65% -> 250, 85% -> 80, 100% -> 0
    // We simulate this with the extractPath
    canvas.drawPath(
      metric.extractPath(0.0, metric.length * extractProgress),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FullScreenBorderPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isResetting != isResetting;
}
