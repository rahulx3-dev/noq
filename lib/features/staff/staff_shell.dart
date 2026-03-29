import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/themes/staff_theme.dart';
import '../../core/utils/app_motion_tokens.dart';
import '../../core/widgets/app_notification_banner.dart';
import '../student/providers/student_alert_provider.dart';
import 'providers/staff_alert_provider.dart';
import 'providers/voice_announcer_service.dart';

class StaffShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const StaffShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the audio alert listener for the staff module
    ref.watch(staffAlertProvider);
    // Initialize the voice announcer
    ref.watch(voiceAnnouncerServiceProvider);

    return Scaffold(
      body: Stack(
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
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 8,
          top: 8,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: StaffTheme.surface,
          border: const Border(top: BorderSide(color: Color(0xFFF3F4F6))),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 20,
              offset: Offset(0, -5),
            )
          ],
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                index: 0,
                icon: Icons.home_filled,
                label: 'Dashboard',
                currentIndex: navigationShell.currentIndex,
              ),
              _buildNavItem(
                context,
                index: 1,
                icon: Icons.soup_kitchen,
                label: 'Kitchen',
                currentIndex: navigationShell.currentIndex,
              ),
              _buildNavItem(
                context,
                index: 2,
                icon: Icons.person,
                label: 'Profile',
                currentIndex: navigationShell.currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required int currentIndex,
  }) {
    final isSelected = index == currentIndex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onItemTapped(index, context),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? StaffTheme.primary.withOpacity(0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isSelected ? StaffTheme.primary : StaffTheme.textSecondary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? StaffTheme.primary : StaffTheme.textSecondary,
              ),
            ),
          ],
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
