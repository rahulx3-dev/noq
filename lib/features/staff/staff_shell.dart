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
      extendBody: true,
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
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: 24, left: 40, right: 40),
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
