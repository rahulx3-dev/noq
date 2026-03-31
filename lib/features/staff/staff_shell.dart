import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/themes/staff_theme.dart';
import '../../core/utils/app_motion_tokens.dart';
import '../../core/widgets/app_notification_banner.dart';
import '../student/providers/student_alert_provider.dart';
import 'providers/staff_alert_provider.dart';
import 'providers/voice_announcer_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers.dart';

class StaffShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const StaffShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the audio alert listener for the staff module
    ref.watch(staffAlertProvider);
    // Initialize the voice announcer
    ref.watch(voiceAnnouncerServiceProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          extendBody: true,
          body: Row(
            children: [
              if (isDesktop) _buildStaffSidebar(context, ref),
              Expanded(
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotionTokens.standard,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.01, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: navigationShell,
                    ),
                    // We watch studentAlertProvider for global notifications
                    Consumer(
                      builder: (context, ref, _) {
                        final currentAlert = ref.watch(studentAlertProvider);
                        if (currentAlert == null) return const SizedBox.shrink();
                        return Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            child: AppNotificationBanner(
                              title: currentAlert.title,
                              body: currentAlert.body,
                              token: currentAlert.token,
                              type: currentAlert.type,
                              onViewOrder: () {
                                ref.read(studentAlertProvider.notifier).dismiss();
                              },
                              onViewMenu: () {
                                ref.read(studentAlertProvider.notifier).dismiss();
                              },
                              onDismiss: () {
                                ref.read(studentAlertProvider.notifier).dismiss();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.only(
                    bottom: isMobile ? 24 : 32,
                    left: isMobile ? 40 : 80,
                    right: isMobile ? 40 : 80,
                  ),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: StaffTheme.primary,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(Icons.home_rounded, 0, navigationShell.currentIndex, context),
                        _buildNavItem(Icons.soup_kitchen_rounded, 1, navigationShell.currentIndex, context),
                        _buildNavItem(Icons.person_rounded, 2, navigationShell.currentIndex, context),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStaffSidebar(BuildContext context, WidgetRef ref) {
    final selectedIndex = navigationShell.currentIndex;
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: StaffTheme.primary,
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 64),
          const Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            'staff portal',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 64),
          _sidebarItem(Icons.home_rounded, 'Home', 0, selectedIndex, context),
          _sidebarItem(Icons.soup_kitchen_rounded, 'Kitchen BOH', 1, selectedIndex, context),
          _sidebarItem(Icons.person_rounded, 'Profile', 2, selectedIndex, context),
          const Spacer(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            leading: const Icon(Icons.logout_rounded, color: Colors.white70),
            title: Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, int index, int currentIndex, BuildContext context) {
    bool isActive = index == currentIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => _onItemTapped(index, context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        leading: Icon(icon, color: isActive ? Colors.white : Colors.white60),
        title: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isActive ? Colors.white : Colors.white60,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, int currentIndex, BuildContext context) {
    bool isActive = index == currentIndex;
    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon, 
          color: Colors.white, 
          size: 19,
        ),
      ),
    );
  }

  void _onItemTapped(int index, BuildContext context) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
