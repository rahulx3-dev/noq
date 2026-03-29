import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_motion_tokens.dart';
import '../../core/widgets/app_notification_banner.dart';
import '../student/providers/student_alert_provider.dart';
import '../../app/themes/admin_theme.dart';
import '../../core/providers.dart';
import './services/admin_notification_service.dart';
import './services/admin_carry_over_service.dart';
import '../../core/models/admin_notification_model.dart';

class AdminShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Carry Over Listener ──────────────────────────────────────────────
    ref.listen(adminNotificationsStreamProvider, (previous, next) {
      final notifications = next.valueOrNull ?? [];
      if (notifications.isEmpty) return;

      // Find the most recent unread carry_over action
      final carryOverAction = notifications.where((n) => 
        !n.isRead && 
        n.type == AdminNotificationType.action && 
        n.actionType == 'carry_over'
      ).toList();

      if (carryOverAction.isNotEmpty) {
        final action = carryOverAction.first;
        final sId = action.sessionId;
        if (sId != null) {
          // Mark as read immediately to prevent multiple popups
          ref.read(adminNotificationServiceProvider).markAsRead(action.id);
          
          // Trigger the popup
          ref.read(adminCarryOverServiceProvider).prepareAndShowCarryOver(
            context: context,
            sessionId: sId,
            sessionName: action.metadata?['sessionName'] ?? 'Session',
            onProcessed: () {},
          );
        }
      }
    });

    final currentAlert = ref.watch(studentAlertProvider);
    return Theme(
      data: AdminTheme.theme(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return Scaffold(
            body: Stack(
              children: [
                Row(
                  children: [
                    if (isDesktop) _buildSidebar(context, ref),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotionTokens.standard,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
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
                    ),
                  ],
                ),
                if (currentAlert != null)
                  Positioned(
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
                  ),
              ],
            ),
            bottomNavigationBar: isDesktop
                ? null
                : BottomNavigationBar(
                    currentIndex: navigationShell.currentIndex,
                    onTap: (index) => _onItemTapped(index, context),
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard_outlined),
                        activeIcon: Icon(Icons.dashboard),
                        label: 'Dashboard',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.rocket_launch_outlined),
                        activeIcon: Icon(Icons.rocket_launch),
                        label: 'Release',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.restaurant_menu_outlined),
                        activeIcon: Icon(Icons.restaurant_menu),
                        label: 'Menu',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.live_tv_outlined),
                        activeIcon: Icon(Icons.live_tv),
                        label: 'Live',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.receipt_outlined),
                        activeIcon: Icon(Icons.receipt),
                        label: 'Orders',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.analytics_outlined),
                        activeIcon: Icon(Icons.analytics),
                        label: 'Reports',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.calendar_month_outlined),
                        activeIcon: Icon(Icons.calendar_month),
                        label: 'Schedule',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.people_outline),
                        activeIcon: Icon(Icons.people),
                        label: 'Staff',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline),
                        activeIcon: Icon(Icons.person),
                        label: 'Profile',
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref) {
    final selectedIndex = navigationShell.currentIndex;
    final theme = Theme.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.black, // Premium Black theme
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),
          const SizedBox(height: 32),
          // Stylized Brand Header
          Center(
            child: Text(
              'noq',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 64, // Matches "big" request, slightly scaled for sidebar
                fontWeight: FontWeight.w800,
                letterSpacing: -4,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const SizedBox(height: 64),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSidebarItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => _onItemTapped(0, context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.rocket_launch_outlined,
                  label: 'Menu Release',
                  isSelected: selectedIndex == 1,
                  onTap: () => _onItemTapped(1, context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.restaurant_menu_outlined,
                  label: 'Menu Management',
                  isSelected: selectedIndex == 2,
                  onTap: () => _onItemTapped(2, context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.live_tv_outlined,
                  label: 'Live Menu View',
                  isSelected: selectedIndex == 3,
                  onTap: () => _onItemTapped(3, context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.receipt_outlined,
                  label: 'Orders',
                  isSelected: selectedIndex == 4,
                  onTap: () => _onItemTapped(4, context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.analytics_outlined,
                  label: 'Stats & Reports',
                  isSelected: selectedIndex == 5,
                  onTap: () => _onItemTapped(5, context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.calendar_month_outlined,
                  label: 'Session Scheduler',
                  isSelected: selectedIndex == 6,
                  onTap: () => _onItemTapped(6, context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.people_outline,
                  label: 'Staff Management',
                  isSelected: selectedIndex == 7,
                  onTap: () => _onItemTapped(7, context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.person_outline,
                  label: 'Admin Profile',
                  isSelected: selectedIndex == 8,
                  onTap: () => _onItemTapped(8, context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSidebarItem(
              context,
              icon: Icons.logout_rounded,
              label: 'Logout',
              isSelected: false,
              onTap: () async {
                  final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      'Confirm Logout',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to log out from the Admin system?',
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          'Log Out',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authServiceProvider).signOut();
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          _buildUserProfileCard(theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white60,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Text('A', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin User',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'View Profile',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert, color: Colors.white38, size: 18),
        ],
      ),
    );
  }

  void _onItemTapped(int index, BuildContext context) {
    navigationShell.goBranch(
      index,
      initialLocation: true,
    );
  }
}
