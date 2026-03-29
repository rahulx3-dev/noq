import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/themes/student_theme.dart';
import '../../../core/utils/time_helper.dart';

class StudentSuccessReveal extends StatefulWidget {
  final List<String> tokens;
  final VoidCallback onDone;
  final VoidCallback onGoToDashboard;
  final String? slotStartTime;

  const StudentSuccessReveal({
    super.key,
    required this.tokens,
    required this.onDone,
    required this.onGoToDashboard,
    this.slotStartTime,
    this.items = const [],
  });

  final List<dynamic> items; 

  @override
  State<StudentSuccessReveal> createState() => _StudentSuccessRevealState();
}

class _StudentSuccessRevealState extends State<StudentSuccessReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _tokenScale;
  late Animation<double> _tokenOpacity;
  late Animation<double> _descOpacity;
  late Animation<double> _btnsOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.4, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.4, curve: Curves.easeOut),
          ),
        );

    _tokenScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.61, curve: Curves.elasticOut),
      ),
    );
    _tokenOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.55, curve: Curves.easeOut),
      ),
    );

    _descOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.8, curve: Curves.easeOut),
      ),
    );

    _btnsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _WritingCheckmark(
                      controller: _controller,
                      color: StudentTheme.statusGreen,
                      size: 100,
                    ),
                    const SizedBox(height: 32),

                    Opacity(
                      opacity: _titleOpacity.value,
                      child: Transform.translate(
                        offset: _titleSlide.value * 20,
                        child: Column(
                          children: [
                            Text(
                              'Order Confirmed!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: StudentTheme.primary,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Yay! Your food is being prepared. Present this token at the counter.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                color: StudentTheme.textSecondary,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    Opacity(
                      opacity: _tokenOpacity.value,
                      child: Transform.scale(
                        scale: _tokenScale.value,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: StudentTheme.primary,
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'YOUR TOKEN${widget.tokens.length > 1 ? "S" : ""}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white54,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                widget.tokens.map((t) => '#$t').join(", "),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -3,
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Dashed line
                              Row(
                                children: [
                                  Container(width: 8, height: 16, decoration: BoxDecoration(color: StudentTheme.background, borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)))),
                                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: List.generate(20, (i) => Expanded(child: Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 2), color: Colors.white.withValues(alpha: 0.15))))))),
                                  Container(width: 8, height: 16, decoration: BoxDecoration(color: StudentTheme.background, borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)))),
                                ],
                              ),
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Items: ${widget.tokens.length}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final bool allPreReady = widget.items.every((it) => it['isPreReady'] == true);
                                      final String remaining = widget.slotStartTime != null 
                                          ? TimeHelper.calculateRemainingTime(widget.slotStartTime!)
                                          : 'Ready soon';
                                      
                                      String displayStatus;
                                      Color statusColor = StudentTheme.accent;
                                      
                                      if (allPreReady) {
                                        displayStatus = 'Ready';
                                        statusColor = StudentTheme.statusGreen;
                                      } else if (remaining == 'Ready') {
                                        // Slot has started, so it's being prepared
                                        displayStatus = 'Preparing';
                                      } else {
                                        displayStatus = 'Ready in $remaining';
                                      }

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              allPreReady ? Icons.check_circle_rounded : Icons.schedule_rounded, 
                                              color: statusColor, 
                                              size: 14
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              displayStatus,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: statusColor,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Opacity(
                      opacity: _descOpacity.value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: StudentTheme.accent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: StudentTheme.accent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please arrive 5 mins before your slot to avoid rush. Your food stays warm!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: StudentTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    Opacity(
                      opacity: _btnsOpacity.value,
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton(
                              onPressed: widget.onDone,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: StudentTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'VIEW ORDER DETAILS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: widget.onGoToDashboard,
                            child: Text(
                              'Back to Home',
                              style: GoogleFonts.plusJakartaSans(
                                color: StudentTheme.textTertiary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Opacity(
                      opacity: _tokenOpacity.value,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ORDER SUMMARY',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: StudentTheme.textTertiary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...widget.items.map((item) {
                            final bool isPreReady = item['isPreReady'] ?? false;
                            final String? sStart = item['selectedSlotStartTime'];
                            final String? sEnd = item['selectedSlotEndTime'];
                            final String status = item['itemStatus'] ?? (isPreReady ? 'ready' : 'pending');
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: StudentTheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['nameSnapshot'] ?? item['name']} x${item['quantity']}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          sStart != null ? 'Slot: $sStart - $sEnd' : (isPreReady ? 'Ready Now' : 'Pending prep'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusBadge(status),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'ready':
        color = StudentTheme.statusGreen;
        break;
      case 'served':
        color = StudentTheme.statusGreen;
        break;
      case 'preparing':
        color = StudentTheme.accent;
        break;
      default:
        color = StudentTheme.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _WritingCheckmark extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;

  const _WritingCheckmark({
    required this.controller,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final Animation<double> drawProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
      ),
    );

    final Animation<double> backgroundOpacity = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.4, 0.6, curve: Curves.easeIn),
      ),
    );

    final Animation<double> backgroundScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.4, 0.7, curve: Curves.elasticOut),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: backgroundScale.value,
              child: Container(
                width: size * 1.5,
                height: size * 1.5,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: backgroundOpacity.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _CheckmarkPainter(
                  progress: drawProgress.value,
                  color: color,
                  strokeWidth: 8,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double w = size.width;
    final double h = size.height;
    
    final p1 = Offset(w * 0.2, h * 0.5);
    final p2 = Offset(w * 0.45, h * 0.75);
    final p3 = Offset(w * 0.8, h * 0.3);

    final double len1 = (p2 - p1).distance;
    final double len2 = (p3 - p2).distance;
    final double totalLen = len1 + len2;
    final double currentLen = progress * totalLen;

    path.moveTo(p1.dx, p1.dy);

    if (currentLen <= len1) {
      final double ratio = currentLen / len1;
      final Offset currentP = Offset.lerp(p1, p2, ratio)!;
      path.lineTo(currentP.dx, currentP.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final double ratio = (currentLen - len1) / len2;
      final Offset currentP = Offset.lerp(p2, p3, ratio)!;
      path.lineTo(currentP.dx, currentP.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) => oldDelegate.progress != progress;
}
