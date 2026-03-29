import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../../../app/themes/admin_theme.dart';
import '../../../app/app_routes.dart';
import '../../../core/models/admin_notification_model.dart';
import '../services/admin_notification_service.dart';
import '../services/admin_carry_over_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';


class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AdminTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, size: 20),
            tooltip: 'Mark all as read',
            onPressed: () => ref.read(adminNotificationServiceProvider).markAllAsRead(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            tooltip: 'Clear all',
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          final grouped = _groupNotifications(notifications);
          final keys = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final dateLabel = keys[index];
              final items = grouped[dateLabel]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text(
                      dateLabel.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...items.map((n) => _NotificationCard(notification: n)),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading notifications: $e')),
      ),
    );
  }

  Map<String, List<AdminNotification>> _groupNotifications(List<AdminNotification> notifications) {
    final Map<String, List<AdminNotification>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var n in notifications) {
      final nDate = DateTime(n.timestamp.year, n.timestamp.month, n.timestamp.day);
      String label;
      if (nDate == today) {
        label = 'Today';
      } else if (nDate == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('dd MMM yyyy').format(nDate);
      }

      if (!grouped.containsKey(label)) {
        grouped[label] = [];
      }
      grouped[label]!.add(n);
    }
    return grouped;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 64, color: AdminTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AdminTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all?'),
        content: const Text('This will delete all notification history permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(adminNotificationServiceProvider).clearAll();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final AdminNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isActionable = notification.actionType != null;
    
    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          ref.read(adminNotificationServiceProvider).markAsRead(notification.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead ? AdminTheme.border : AdminTheme.primary.withValues(alpha: 0.1),
          ),
          boxShadow: notification.isRead 
            ? [] 
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(),
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
                          notification.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AdminTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(notification.timestamp),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AdminTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AdminTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (isActionable) ...[
                    const SizedBox(height: 12),
                    _buildActions(context, ref),
                  ],
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 8),
                decoration: const BoxDecoration(
                  color: AdminTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;
    Color bgColor;

    switch (notification.type) {
      case AdminNotificationType.reminder:
        icon = Icons.alarm;
        color = Colors.orange.shade800;
        bgColor = Colors.orange.shade50;
        break;
      case AdminNotificationType.alert:
        icon = Icons.warning_amber_rounded;
        color = Colors.red.shade800;
        bgColor = Colors.red.shade50;
        break;
      case AdminNotificationType.success:
        icon = Icons.check_circle_outline;
        color = Colors.green.shade800;
        bgColor = Colors.green.shade50;
        break;
      case AdminNotificationType.action:
        icon = Icons.bolt;
        color = AdminTheme.primary;
        bgColor = AdminTheme.primary.withValues(alpha: 0.1);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    if (notification.actionType == 'release') {
      return ElevatedButton(
        onPressed: () {
          ref.read(adminNotificationServiceProvider).markAsRead(notification.id);
          context.push(AppRoutes.adminRelease);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: const Text('Release Menu', style: TextStyle(fontSize: 13)),
      );
    }
    
    if (notification.actionType == 'carry_over') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ref.read(adminNotificationServiceProvider).markAsRead(notification.id);
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(0, 36),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('Dismiss', style: TextStyle(fontSize: 13, color: AdminTheme.textSecondary)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleCarryOver(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), // Emerald/Green for success-y actions
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(0, 36),
                elevation: 0,
              ),
              child: const Text('Carry Over', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleCarryOver(BuildContext context, WidgetRef ref) async {
    final sId = notification.sessionId;
    if (sId == null) return;

    ref.read(adminNotificationServiceProvider).markAsRead(notification.id);
    
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    await ref.read(adminCarryOverServiceProvider).prepareAndShowCarryOver(
      context: context,
      sessionId: sId,
      sessionName: notification.metadata?['sessionName'] ?? 'Session',
      onProcessed: () {
        if (context.mounted) Navigator.pop(context); // Remove loading
      },
    );
  }
}
