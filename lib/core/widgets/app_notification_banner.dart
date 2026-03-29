import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/themes/student_theme.dart';
import '../utils/app_motion_tokens.dart';

enum AlertType { success, reminder, ready, status, menu, stock }

class AppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String? token;
  final AlertType type;
  final VoidCallback onViewOrder;
  final VoidCallback onViewMenu;
  final VoidCallback onDismiss;

  const AppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.token,
    required this.type,
    required this.onViewOrder,
    required this.onViewMenu,
    required this.onDismiss,
  });

  @override
  State<AppNotificationBanner> createState() => _AppNotificationBannerState();
}

class _AppNotificationBannerState extends State<AppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotionTokens.slow, // 420ms for a "settle" feel
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppMotionTokens.enterCurve,
    );

    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, -1.2), // Start above viewport
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppMotionTokens.settleCurve,
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _exitAndDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    IconData icon;

    switch (widget.type) {
      case AlertType.ready:
        iconBg = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);
        icon = Icons.restaurant_rounded;
        break;
      case AlertType.success:
        iconBg = const Color(0xFFE3F2FD);
        iconColor = const Color(0xFF1976D2);
        icon = Icons.check_circle_rounded;
        break;
      case AlertType.reminder:
        iconBg = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFF57C00);
        icon = Icons.access_time_filled_rounded;
        break;
      case AlertType.status:
        iconBg = const Color(0xFFF3E5F5);
        iconColor = const Color(0xFF7B1FA2);
        icon = Icons.info_rounded;
        break;
      case AlertType.menu:
        iconBg = const Color(0xFFE0F7FA);
        iconColor = const Color(0xFF0097A7);
        icon = Icons.restaurant_menu_rounded;
        break;
      case AlertType.stock:
        iconBg = const Color(0xFFFFFDE7);
        iconColor = const Color(0xFFFBC02D);
        icon = Icons.inventory_2_rounded;
        break;
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dismissible(
          key: const ValueKey('notification_banner'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => widget.onDismiss(),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FFF9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: iconColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.title.toUpperCase(),
                                style: GoogleFonts.lexend(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: iconColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.token != null
                              ? 'Token #${widget.token}: ${widget.body}'
                              : widget.body,
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: StudentTheme.textOnLight,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (widget.type == AlertType.menu || widget.type == AlertType.stock)
                                ? widget.onViewMenu
                                : widget.onViewOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StudentTheme.primaryOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              (widget.type == AlertType.menu || widget.type == AlertType.stock)
                                  ? 'View Menu'
                                  : 'View Order',
                              style: GoogleFonts.lexend(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: StudentTheme.textTertiary,
                      onPressed: _exitAndDismiss,
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
