import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/themes/student_theme.dart';
import '../../../core/providers.dart';
import '../services/student_notification_service.dart';

class StudentNotificationsScreen extends ConsumerWidget {
  const StudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    final notificationsAsync = ref.watch(historicalNotificationsProvider);
    final notificationService = ref.read(studentNotificationServiceProvider);

    return Scaffold(
      backgroundColor: StudentTheme.background,
      appBar: AppBar(
        backgroundColor: StudentTheme.background,
        elevation: 0,
        toolbarHeight: 85,
        leadingWidth: 72,
        leading: Center(
          child: Container(
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: StudentTheme.primary,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: StudentTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
             decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, color: StudentTheme.primary, size: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              offset: const Offset(0, 50),
              onSelected: (value) {
                if (value == 'read_all') {
                  notificationService.readAll();
                } else if (value == 'clear_all') {
                  notificationService.clearAll();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      const Icon(Icons.done_all_rounded, size: 18, color: StudentTheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Read All',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 12),
                      Text(
                        'Clear All',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState(ref);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(context, notification, ref);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: StudentTheme.primary, strokeWidth: 3),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: GoogleFonts.plusJakartaSans(color: StudentTheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: StudentTheme.primary.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 56,
                color: StudentTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No notifications yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: StudentTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You're all caught up! New updates about your orders and tokens will appear here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: StudentTheme.textSecondary,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: () => ref.invalidate(historicalNotificationsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Refresh',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    Map<String, dynamic> data,
    WidgetRef ref,
  ) {
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final type = data['type'] ?? 'info';
    final isRead = data['isRead'] ?? false;
    final docId = data['id'];

    Color iconColor;
    IconData iconData;

    switch (type) {
      case 'success':
        iconColor = StudentTheme.statusGreen;
        iconData = Icons.check_circle_rounded;
        break;
      case 'warning':
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.warning_rounded;
        break;
      case 'error':
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.error_rounded;
        break;
      case 'menu':
        iconColor = const Color(0xFF06B6D4);
        iconData = Icons.restaurant_menu_rounded;
        break;
      case 'stock':
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.inventory_2_rounded;
        break;
      case 'order_ready':
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.restaurant_rounded;
        break;
      case 'order_served':
        iconColor = StudentTheme.statusGreen;
        iconData = Icons.verified_rounded;
        break;
      case 'order_skipped':
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.timer_off_rounded;
        break;
      default:
        iconColor = StudentTheme.primary;
        iconData = Icons.notifications_rounded;
    }

    return GestureDetector(
      onTap: () {
        if (!isRead && docId != null) {
          ref.read(studentNotificationServiceProvider).markAsRead(docId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isRead ? StudentTheme.background.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isRead ? Colors.transparent : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: isRead 
            ? null 
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isRead ? StudentTheme.textSecondary : StudentTheme.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(createdAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: StudentTheme.textSecondary.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: StudentTheme.textSecondary,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }
}

// Redundant local provider removed in favor of StudentNotificationService
