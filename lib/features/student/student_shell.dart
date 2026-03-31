import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_routes.dart';
import 'providers/student_orders_provider.dart';
import 'providers/student_alert_provider.dart';
import 'providers/student_providers.dart';
import '../../core/models/student_models.dart';
import '../../core/utils/app_motion_tokens.dart';
import '../../core/widgets/app_notification_banner.dart';
import 'services/student_voice_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/themes/student_theme.dart';
import '../../core/providers.dart';

class StudentShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const StudentShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize global student voice service
    ref.watch(studentVoiceServiceProvider);
    // Listen for RAW order stream so per-item itemStatus changes hit processOrderUpdates.
    // Using the aggregated provider loses individual item status transitions.
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(studentOrdersStreamProvider, (
      previous,
      next,
    ) {
      final prevData = previous?.value;
      final nextData = next.value;
      if (nextData != null) {
        ref.read(studentAlertProvider.notifier).processOrderUpdates(prevData, nextData);
        
        // Use a set to collect tokens to notify in this single update
        final Set<String> newTokens = {};
        final now = DateTime.now();

        for (var order in nextData) {
          final isCalledNow = order['isCalledForPickup'] == true;
          if (!isCalledNow) continue;

          final prevOrder = prevData?.firstWhere(
            (o) => o['orderId'] == order['orderId'],
            orElse: () => {},
          );
          final wasCalledPreviously = prevOrder?['isCalledForPickup'] == true;
          final prevLastCalled = prevOrder?['lastCalledAt'] as Timestamp?;
          final nextLastCalled = order['lastCalledAt'] as Timestamp?;

          bool isRecent = false;
          if (nextLastCalled != null) {
            final calledTime = nextLastCalled.toDate();
            // Only alert if the call happened in the last 60 seconds
            isRecent = now.difference(calledTime).inSeconds < 60;
          }

          bool shouldNotifyThisOrder = false;

          // If we don't have previous data (initial load), only notify if the timestamp is EXTREMELY recent
          if (prevData == null) {
            if (isRecent) shouldNotifyThisOrder = true;
          } else {
            if (!wasCalledPreviously && isRecent) {
              shouldNotifyThisOrder = true;
            } else if (prevLastCalled != null && nextLastCalled != null && 
                       (nextLastCalled.seconds > prevLastCalled.seconds || 
                        (nextLastCalled.seconds == prevLastCalled.seconds && nextLastCalled.nanoseconds > prevLastCalled.nanoseconds))) {
              shouldNotifyThisOrder = true;
            }
          }

          if (shouldNotifyThisOrder) {
            final token = order['tokenNumber']?.toString() ?? '';
            if (token.isNotEmpty) newTokens.add(token);
          }
        }

        if (newTokens.isNotEmpty) {
          final consolidatedTokens = newTokens.join(', ');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (ctx) => _TokenCallDialog(token: consolidatedTokens),
              );
            }
          });
        }
      }
    });

    // Listen for menu updates (Real-time banners)
    ref.listen<AsyncValue<StudentDailyMenu?>>(todayStudentMenuProvider, (
      previous,
      next,
    ) {
      if (next is AsyncData<StudentDailyMenu?>) {
        ref
            .read(studentAlertProvider.notifier)
            .processMenuUpdates(previous?.value, next.value);
      }
    });

    final currentAlert = ref.watch(studentAlertProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          extendBody: true,
          body: Row(
            children: [
              if (isDesktop) _buildStudentSidebar(context, ref),
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
                              context.go(AppRoutes.studentToken);
                            },
                            onViewMenu: () {
                              ref.read(studentAlertProvider.notifier).dismiss();
                              context.go(AppRoutes.studentDashboard);
                            },
                            onDismiss: () {
                              ref.read(studentAlertProvider.notifier).dismiss();
                            },
                          ),
                        ),
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
                    bottom: isMobile ? 18 : 32,
                    left: isMobile ? 40 : 80,
                    right: isMobile ? 40 : 80,
                  ),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: StudentTheme.primary,
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
                        _navItem(Icons.home_rounded, 0, navigationShell.currentIndex, context),
                        _navItem(Icons.receipt_long_rounded, 1, navigationShell.currentIndex, context),
                        _navItem(Icons.confirmation_num_rounded, 2, navigationShell.currentIndex, context),
                        _navItem(Icons.person_rounded, 3, navigationShell.currentIndex, context),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStudentSidebar(BuildContext context, WidgetRef ref) {
    final selectedIndex = navigationShell.currentIndex;
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: StudentTheme.primary,
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 64),
          Text(
            'noq',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -3,
            ),
          ),
          const SizedBox(height: 64),
          _sidebarItem(Icons.home_rounded, 'Dashboard', 0, selectedIndex, context),
          _sidebarItem(Icons.receipt_long_rounded, 'Orders', 1, selectedIndex, context),
          _sidebarItem(Icons.confirmation_num_rounded, 'Token', 2, selectedIndex, context),
          _sidebarItem(Icons.person_rounded, 'Profile', 3, selectedIndex, context),
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

  Widget _navItem(IconData icon, int index, int currentIndex, BuildContext context) {
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

class _TokenCallDialog extends StatelessWidget {
  final String token;

  const _TokenCallDialog({required this.token});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: StudentTheme.statusGreen.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: StudentTheme.statusGreen.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: StudentTheme.statusGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: StudentTheme.statusGreen,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'TOKEN CALLED',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: StudentTheme.statusGreen,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '#$token',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please proceed to the counter to collect your order.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentTheme.statusGreen,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Got it',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

