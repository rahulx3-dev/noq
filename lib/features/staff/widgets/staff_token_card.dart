import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/themes/staff_theme.dart';

class StaffTokenCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final String orderId;

  const StaffTokenCard({super.key, required this.order, required this.orderId});

  @override
  ConsumerState<StaffTokenCard> createState() => _StaffTokenCardState();
}

class _StaffTokenCardState extends ConsumerState<StaffTokenCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final rawStatus = (order['statusCategory'] as String? ?? 'pending').toLowerCase();
    final tokenNumber = order['tokenNumber'] ?? '--';
    final studentName = order['studentName'] ?? 'Unknown Student';
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final isCalledForPickup = order['isCalledForPickup'] as bool? ?? false;

    // Derived counts for display override
    int servedCount = 0;
    int readyCount = 0;
    for (var it in items) {
      final s = (it['itemStatus'] as String? ?? 'pending').toLowerCase();
      if (s == 'served') servedCount++;
      else if (s == 'ready') readyCount++;
    }

    // Override: If technically 'partial' but 0 served, treat as 'pending' (PREP)
    // This ensures mixed Pre-ready + Normal items initially appear Green.
    String status = rawStatus;
    if (rawStatus == 'partial' && servedCount == 0) {
      status = 'pending';
    } else if (rawStatus == 'pending' && readyCount == items.length && items.isNotEmpty) {
      status = 'ready';
    }

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _getCardBackgroundColor(status),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getCardBorderColor(status),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              offset: Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _getTokenBoxColor(status),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getTokenBorderColor(status),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$tokenNumber',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getTokenTextColor(status),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TOKEN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getTokenLabelColor(status),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: StaffTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Has ${items.length} items',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: StaffTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(status, isCalledForPickup),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildPriorityReminder(status, items, order),
                        ...items.map((item) => _buildItemRow(item, status)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildActionButtons(status, context, items, isCalledForPickup),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityReminder(String status, List<Map<String, dynamic>> items, Map<String, dynamic> data) {
    bool isUrgent = false;
    String msg = '';
    Color color = Colors.red;

    if (status == 'partial') {
      isUrgent = true;
      msg = 'PARTIAL SERVED - CONTINUE PREP';
      color = StaffTheme.statusPartial;
    } else if (status == 'skipped') {
      final anyItemReady = items.any((item) {
        final iStatus = (item['itemStatus'] as String? ?? '').toLowerCase();
        return iStatus == 'ready' || iStatus == 'served';
      });
      final readyBeforeSkip = data['readyBeforeSkip'] as bool? ?? anyItemReady;
      
      if (!readyBeforeSkip) {
        isUrgent = true;
        msg = 'SKIPPED - NEEDS URGENT PREP';
        color = StaffTheme.statusSkipped;
      }
    }

    if (!isUrgent) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.priority_high_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Colors using StaffTheme tokens ──────────────────────────

  Color _getCardBackgroundColor(String status) {
    switch (status) {
      case 'ready':
        return StaffTheme.statusReady.withValues(alpha: 0.06);
      case 'skipped':
        return StaffTheme.statusSkipped.withValues(alpha: 0.06);
      case 'partial':
        return StaffTheme.statusPartial.withValues(alpha: 0.06);
      case 'served':
        return StaffTheme.statusReady.withValues(alpha: 0.04);
      default:
        return StaffTheme.surface;
    }
  }

  Color _getCardBorderColor(String status) {
    switch (status) {
      case 'ready':
        return StaffTheme.statusReady.withValues(alpha: 0.3);
      case 'skipped':
        return StaffTheme.statusSkipped.withValues(alpha: 0.3);
      case 'partial':
        return StaffTheme.statusPartial.withValues(alpha: 0.3);
      case 'served':
        return StaffTheme.statusReady.withValues(alpha: 0.2);
      default:
        return StaffTheme.border;
    }
  }

  Color _getTokenBoxColor(String status) {
    switch (status) {
      case 'ready':
      case 'served':
      case 'skipped':
      case 'partial':
        return Colors.white;
      default:
        return StaffTheme.secondary;
    }
  }

  Color _getTokenBorderColor(String status) {
    switch (status) {
      case 'ready':
      case 'served':
        return StaffTheme.statusReady.withValues(alpha: 0.3);
      case 'skipped':
        return StaffTheme.statusSkipped.withValues(alpha: 0.3);
      case 'partial':
        return StaffTheme.statusPartial.withValues(alpha: 0.3);
      default:
        return StaffTheme.primary.withValues(alpha: 0.1);
    }
  }

  Color _getTokenTextColor(String status) {
    switch (status) {
      case 'ready':
      case 'served':
        return StaffTheme.statusReady;
      case 'skipped':
        return StaffTheme.statusSkipped;
      case 'partial':
        return StaffTheme.statusPartial;
      default:
        return StaffTheme.primary;
    }
  }

  Color _getTokenLabelColor(String status) {
    switch (status) {
      case 'ready':
      case 'served':
        return StaffTheme.statusReady.withValues(alpha: 0.7);
      case 'skipped':
        return StaffTheme.statusSkipped.withValues(alpha: 0.7);
      case 'partial':
        return StaffTheme.statusPartial.withValues(alpha: 0.7);
      default:
        return Colors.grey.shade400;
    }
  }

  // ── Status Badge ──────────────────────────────────────────────────

  Widget _buildStatusBadge(String status, bool isCalledForPickup) {
    Color bg;
    Color text;
    Color border;
    String label;

    switch (status) {
      case 'skipped':
        bg = StaffTheme.statusSkipped.withValues(alpha: 0.15);
        text = StaffTheme.statusSkipped;
        border = StaffTheme.statusSkipped.withValues(alpha: 0.3);
        label = 'SKIPPED';
        break;
      case 'ready':
        if (isCalledForPickup) {
          bg = Colors.orange.withValues(alpha: 0.15);
          text = Colors.orange;
          border = Colors.orange.withValues(alpha: 0.3);
          label = 'NOW SERVING';
        } else {
          bg = StaffTheme.statusReady.withValues(alpha: 0.15);
          text = StaffTheme.statusReady;
          border = StaffTheme.statusReady.withValues(alpha: 0.3);
          label = 'READY';
        }
        break;
      case 'partial':
        bg = StaffTheme.statusPartial.withValues(alpha: 0.15);
        text = StaffTheme.statusPartial;
        border = StaffTheme.statusPartial.withValues(alpha: 0.3);
        label = 'PARTIAL';
        break;
      case 'served':
        bg = StaffTheme.statusReady.withValues(alpha: 0.15);
        text = StaffTheme.statusReady;
        border = StaffTheme.statusReady.withValues(alpha: 0.3);
        label = 'SERVED';
        break;
      case 'scheduled':
        bg = Colors.blue.withValues(alpha: 0.1);
        text = Colors.blue.shade600;
        border = Colors.blue.withValues(alpha: 0.2);
        label = 'SCHEDULED';
        break;
      default:
        bg = StaffTheme.statusPending.withValues(alpha: 0.1);
        text = StaffTheme.statusPending;
        border = StaffTheme.statusPending.withValues(alpha: 0.2);
        label = 'PREP';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Item Row ──────────────────────────────────────────────────────

  Widget _buildItemRow(Map<String, dynamic> item, String status) {
    final name = item['nameSnapshot'] ?? 'Item';
    final qty = item['quantity'] ?? 1;
    final itemStatus = item['itemStatus'] as String? ?? 'pending';
    final isServed = itemStatus == 'served';
    final isReadyOnly = itemStatus == 'ready';

    Color dotColor = StaffTheme.primary.withValues(alpha: 0.4);
    if (status == 'skipped') dotColor = StaffTheme.statusSkipped.withValues(alpha: 0.6);
    if (status == 'ready' || status == 'served' || itemStatus == 'ready' || itemStatus == 'served') {
      dotColor = StaffTheme.statusReady;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (isServed && status == 'partial') ...[
             const Icon(Icons.check_circle, size: 14, color: StaffTheme.statusReady),
             const SizedBox(width: 8),
          ] else if (isReadyOnly && status == 'partial') ...[
             const Icon(Icons.check, size: 14, color: StaffTheme.statusReady),
             const SizedBox(width: 8),
          ] else if (itemStatus == 'pending' && status == 'partial') ...[
             const Icon(Icons.pending, size: 14, color: StaffTheme.statusPartial),
             const SizedBox(width: 8),
          ] else ...[
             Container(
               width: 6,
               height: 6,
               decoration: BoxDecoration(
                 color: dotColor,
                 shape: BoxShape.circle,
               ),
             ),
             const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              '$qty x $name',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: (itemStatus == 'pending' && status == 'partial') ? FontWeight.bold : FontWeight.normal,
                color: isServed ? Colors.grey.shade500 : StaffTheme.textPrimary,
                decoration: isServed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirmation Dialog ──────────────────────────────────────────

  Future<void> _handleCallAction() async {
    try {
      final String orderId = widget.orderId;
      if (orderId.isEmpty) return;

      // 1. Update the order state first (THIS TRIGGERS THE STUDENT POPUP)
      await FirebaseFirestore.instance
          .collection('canteens')
          .doc('default')
          .collection('orders')
          .doc(orderId)
          .update({
        'isCalledForPickup': true,
        'lastCalledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Silently try to notify the student (FOR THE HISTORY SCREEN)
      try {
        // Resolve student identification for notification
        final dynamic rawId = widget.order['studentId'] ?? 
                             widget.order['studentUid'] ?? 
                             widget.order['uid'];
        final String studentId = (rawId ?? '').toString().trim();

        if (studentId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(studentId)
              .collection('notifications')
              .add({
            'title': 'Order Ready! 🥣',
            'body': 'Token #${widget.order['tokenNumber'] ?? '--'} is ready! Please come to the counter.',
            'type': 'order_ready',
            'orderId': orderId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      } catch (notiError) {
        // Log notification failure (often due to Firestore rules) but don't stop the flow
        debugPrint('Notification log failed (likely permission): $notiError');
      }
    } catch (e) {
      debugPrint('ERROR: Critical _handleCallAction core failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to call student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(BuildContext context, String actionName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StaffTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Action',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: StaffTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to mark this token as $actionName?',
          style: GoogleFonts.plusJakartaSans(
            color: StaffTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: StaffTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: StaffTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Confirm',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Action Buttons — STATE MACHINE ────────────────────────────────
  // pending  → [Partial] [Skip] [Ready]
  // ready    → [SERVE TO CUSTOMER]           ← READY IS NOT FINAL
  // partial  → [Notes] [Complete Order]
  // skipped  → [Partial] [Skipped(disabled)] [Ready]
  // served   → (no actions)

  Widget _buildActionButtons(String status, BuildContext context, List<dynamic> items, bool isCalledForPickup) {
    if (status == 'served') return const SizedBox.shrink();

    if (status == 'pending') {
      final bool allPreReady = items.every((it) => it['isPreReady'] ?? it['isReadyMade'] ?? false);
      
      // If all items are pre-ready, we skip the "READY" step and go straight to "CALL"
      if (allPreReady) {
        return _buildActionBar(
          borderColor: StaffTheme.statusReady.withValues(alpha: 0.3),
          bgColor: StaffTheme.statusReady.withValues(alpha: 0.05),
          children: [
            Expanded(
              child: _buildCellButton(
                icon: Icons.skip_next,
                label: 'Skip',
                iconColor: StaffTheme.statusSkipped,
                textColor: StaffTheme.statusSkipped,
                onTap: () async {
                  if (await _showConfirmDialog(context, 'Skipped')) {
                    _updateStatus('skipped');
                  }
                },
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.black12),
            Expanded(
              child: _buildCellButton(
                icon: Icons.campaign,
                label: isCalledForPickup ? 'RE-CALL' : 'CALL',
                iconColor: StaffTheme.statusPending,
                textColor: StaffTheme.statusPending,
                onTap: _handleCallAction,
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.black12),
            Expanded(
              child: _buildCellButton(
                icon: Icons.restaurant,
                label: 'SERVE',
                iconColor: Colors.white,
                textColor: Colors.white,
                bg: StaffTheme.statusReady,
                onTap: () async {
                  if (await _showConfirmDialog(context, 'Served')) {
                    _updateStatus('served');
                  }
                },
              ),
            ),
          ],
        );
      }

      final bool hasNonPreReady = items.any((it) => !(it['isPreReady'] ?? it['isReadyMade'] ?? false));
      final showPartial = items.length > 1 && hasNonPreReady;
      return _buildActionBar(
        borderColor: Colors.grey.shade200,
        bgColor: Colors.grey.shade50,
        children: [
          if (showPartial) ...[
            Expanded(
              child: _buildCellButton(
              icon: Icons.remove_shopping_cart,
              label: 'Partial',
              iconColor: StaffTheme.statusPartial,
              textColor: StaffTheme.statusPartial,
              onTap: () async {
                if (await _showConfirmDialog(context, 'Partial')) {
                  await _showItemManagementDialog(context);
                }
              },
            ),
            ),
            const VerticalDivider(width: 1, color: Colors.black12),
          ],
          Expanded(
            child: _buildCellButton(
              icon: Icons.skip_next,
              label: 'Skip',
              iconColor: StaffTheme.statusSkipped,
              textColor: StaffTheme.statusSkipped,
              onTap: () async {
                if (await _showConfirmDialog(context, 'Skipped')) {
                  _updateStatus('skipped');
                }
              },
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),
          Expanded(
            child: _buildCellButton(
              icon: Icons.check_circle,
              label: 'Ready',
              iconColor: Colors.white,
              textColor: Colors.white,
              bg: StaffTheme.primary,
              onTap: () async {
                if (await _showConfirmDialog(context, 'Ready')) {
                  _updateStatus('ready');
                }
              },
            ),
          ),
        ],
      );
    }

    if (status == 'ready') {
      final bool hasNonPreReady = items.any((it) => !(it['isPreReady'] ?? it['isReadyMade'] ?? false));
      final showPartial = items.length > 1 && hasNonPreReady;
      return _buildActionBar(
        borderColor: StaffTheme.statusReady.withValues(alpha: 0.3),
        bgColor: StaffTheme.statusReady.withValues(alpha: 0.05),
        children: [
          if (showPartial) ...[
            Expanded(
              child: _buildCellButton(
                icon: Icons.remove_shopping_cart,
                label: 'Partial',
                iconColor: StaffTheme.statusPartial,
                textColor: StaffTheme.statusPartial,
                onTap: () async {
                  if (await _showConfirmDialog(context, 'Partial')) {
                    await _showItemManagementDialog(context);
                  }
                },
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.black12),
          ],
          
          // Always show CALL/RE-CALL button to allow repeated pings
          Expanded(
            child: _buildCellButton(
              icon: Icons.campaign,
              label: (widget.order['isCalledForPickup'] as bool? ?? false) ? 'RE-CALL' : 'CALL',
              iconColor: StaffTheme.statusPending,
              textColor: StaffTheme.statusPending,
              onTap: _handleCallAction,
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),

          Expanded(
            child: _buildCellButton(
              icon: Icons.skip_next,
              label: 'Skip',
              iconColor: StaffTheme.statusSkipped,
              textColor: StaffTheme.statusSkipped,
              onTap: () async {
                if (await _showConfirmDialog(context, 'Skipped')) {
                  _updateStatus('skipped');
                }
              },
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),
          
          Expanded(
            child: _buildCellButton(
              icon: Icons.restaurant,
              label: 'SERVE',
              iconColor: Colors.white,
              textColor: Colors.white,
              bg: StaffTheme.statusReady,
              onTap: () async {
                if (await _showConfirmDialog(context, 'Served')) {
                  _updateStatus('served');
                }
              },
            ),
          ),
        ],
      );
    }

    if (status == 'partial') {
      return _buildActionBar(
        borderColor: StaffTheme.statusPartial.withValues(alpha: 0.3),
        bgColor: StaffTheme.statusPartial.withValues(alpha: 0.05),
        children: [
          Expanded(
            child: _buildCellButton(
              icon: Icons.campaign,
              label: (widget.order['isCalledForPickup'] as bool? ?? false) ? 'RE-CALL' : 'CALL',
              iconColor: StaffTheme.statusPending,
              textColor: StaffTheme.statusPending,
              onTap: _handleCallAction,
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),
          Expanded(
            child: _buildCellButton(
              icon: Icons.list_alt,
              label: 'Items',
              iconColor: StaffTheme.statusPartial,
              textColor: StaffTheme.statusPartial,
              onTap: () => _showItemManagementDialog(context),
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),
          Expanded(
            child: _buildCellButton(
              icon: Icons.skip_next,
              label: 'Skip',
              iconColor: StaffTheme.statusSkipped,
              textColor: StaffTheme.statusSkipped,
              onTap: () async {
                if (await _showConfirmDialog(context, 'Skipped')) {
                  _updateStatus('skipped');
                }
              },
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),
          Expanded(
            child: _buildCellButton(
              icon: Icons.check_circle,
              label: 'Ready',
              iconColor: Colors.white,
              textColor: Colors.white,
              bg: StaffTheme.primary,
              onTap: () async {
                if (await _showConfirmDialog(context, 'Ready')) {
                  _updateStatus('ready');
                }
              },
            ),
          ),
        ],
      );
    }

    if (status == 'skipped') {
      final readyBeforeSkip = widget.order['readyBeforeSkip'] as bool? ?? false;
      return _buildActionBar(
        borderColor: StaffTheme.statusSkipped.withValues(alpha: 0.3),
        bgColor: StaffTheme.statusSkipped.withValues(alpha: 0.05),
        children: [
          if (readyBeforeSkip) ...[
            // For tokens that were ready but skipped, allow "CALL" again
            Expanded(
              child: _buildCellButton(
                icon: Icons.campaign,
                label: (widget.order['isCalledForPickup'] as bool? ?? false) ? 'RE-CALL' : 'CALL',
                iconColor: StaffTheme.statusPending,
                textColor: StaffTheme.statusPending,
                onTap: _handleCallAction,
              ),
            ),
          ] else ...[
            Expanded(
              child: _buildCellButton(
                icon: Icons.skip_next,
                label: 'Skipped',
                iconColor: Colors.grey.shade400,
                textColor: Colors.grey.shade500,
                onTap: null, // Disabled for non-ready skips
              ),
            ),
          ],
          const VerticalDivider(width: 1, color: Colors.black12),
          Expanded(
            child: _buildCellButton(
              icon: Icons.restaurant,
              label: 'Serve',
              iconColor: Colors.white,
              textColor: Colors.white,
              bg: StaffTheme.statusReady,
              onTap: () async {
                if (await _showConfirmDialog(context, 'Served')) {
                  _updateStatus('served');
                }
              },
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _showItemManagementDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // We use the same order data from the widget, but we need to react to updates.
            // Since this is a stream, the widget will rebuild, but the dialog might not
            // unless we use a stream builder or similar. However, for simplicity and 
            // immediate feedback, we'll perform actions and rely on the fact that
            // we'll update the local state to show current progress.
            
            // Actually, fetching from Firestore for real-time in dialog:
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('canteens')
                  .doc('default')
                  .collection('orders')
                  .doc(widget.orderId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final orderData = snapshot.data!.data() ?? {};
                final List<dynamic> items = orderData['items'] ?? [];

                return AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.list_alt, color: StaffTheme.statusPartial),
                      const SizedBox(width: 12),
                      const Text('Manage Order Items'),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Update status for individual items:', 
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 16),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final status = (item['itemStatus'] as String? ?? 'pending').toLowerCase();
                              final name = item['nameSnapshot'] ?? 'Item';
                              final qty = item['quantity'] ?? 1;

                              final isServed = status == 'served';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  name, 
                                  style: TextStyle(
                                    fontWeight: isServed ? FontWeight.normal : FontWeight.bold,
                                    color: isServed ? Colors.grey.shade500 : Colors.black,
                                    decoration: isServed ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Text('Qty: $qty • Status: ${status.toUpperCase()}'),
                                trailing: _buildItemActionButton(context, index, status, items),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CLOSE'),
                    ),
                  ],
                );
              }
            );
          }
        );
      },
    );
  }

  Widget _buildItemActionButton(BuildContext context, int index, String status, List<dynamic> allItems) {
    if (status == 'served') {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    if (status == 'pending') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: StaffTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () async {
          if (await _showConfirmDialog(context, 'Ready')) {
            await _updateSingleItemStatus(index, 'ready', allItems);
          }
        },
        child: const Text('READY'),
      );
    }

    if (status == 'ready' || status == 'partial') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: StaffTheme.statusReady,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () async {
          if (await _showConfirmDialog(context, 'Served')) {
            await _updateSingleItemStatus(index, 'served', allItems);
          }
        },
        child: const Text('SERVE'),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _updateSingleItemStatus(int index, String newStatus, List<dynamic> allItems) async {
    final updatedItems = List<Map<String, dynamic>>.from(allItems);
    updatedItems[index]['itemStatus'] = newStatus;
    
    // Recalculate counts
    int totalItems = widget.order['totalItemCount'] as int? ?? 0;
    if (totalItems == 0) {
      totalItems = updatedItems.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));
    }

    int pendingCount = 0;
    int readyCount = 0;
    int servedCount = 0;
    int skippedCount = 0;
    
    for (var item in updatedItems) {
      final s = (item['itemStatus'] as String? ?? 'pending').toLowerCase();
      final qty = (item['quantity'] as int? ?? 1);
      if (s == 'ready') {
        readyCount += qty;
      } else if (s == 'served') {
        servedCount += qty;
      } else if (s == 'skipped') {
        skippedCount += qty;
      } else {
        pendingCount += qty;
      }
    }

    // Determine overall order status - ROBUST HIERARCHY
    String finalStatus = 'pending';
    if (servedCount == totalItems) {
      finalStatus = 'served';
    } else if (servedCount > 0) {
      finalStatus = 'partial';
    } else if (readyCount == totalItems) {
      finalStatus = 'ready';
    } else if (skippedCount == totalItems) {
      finalStatus = 'skipped';
    } else {
      finalStatus = 'pending';
    }

    await FirebaseFirestore.instance
        .collection('canteens')
        .doc('default')
        .collection('orders')
        .doc(widget.orderId)
        .update({
          'statusCategory': finalStatus,
          'orderStatus': finalStatus,
          'items': updatedItems,
          'pendingItemCount': pendingCount,
          'readyItemCount': readyCount,
          'servedItemCount': servedCount,
          'skippedItemCount': skippedCount,
          'hasPartialItems': (finalStatus == 'partial' || (servedCount > 0 && servedCount < totalItems)),
          'activeForStaff': (finalStatus != 'served'),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Widget _buildActionBar({
    required Color borderColor,
    required Color bgColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildCellButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    Color bg = Colors.transparent,
    VoidCallback? onTap,
  }) {
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Firestore Update Logic ────────────────────────────────────────
  // CRITICAL: Both statusCategory AND orderStatus must be written
  // so that both Staff dashboard (queries statusCategory) and
  // cross-module screens (read orderStatus) stay in sync.

  Future<void> _updateStatus(String newStatus, {List<int>? selectedIndices}) async {
    final String oldStatus = (widget.order['statusCategory'] as String? ?? 'pending').toLowerCase();
    final items = List<Map<String, dynamic>>.from(widget.order['items'] ?? []);
    int totalItems = widget.order['totalItemCount'] as int? ?? 0;
    if (totalItems == 0) {
      totalItems = items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));
    }

    int pendingCount = 0;
    int readyCount = 0;
    int servedCount = 0;
    int skippedCount = 0;

    if (newStatus == 'ready') {
      // Mark all non-served items as ready
      for (var i = 0; i < items.length; i++) {
        final current = (items[i]['itemStatus'] as String? ?? 'pending').toLowerCase();
        if (current != 'served') {
          items[i]['itemStatus'] = 'ready';
        }
      }
    } else if (newStatus == 'served') {
      // Final serve — mark all items as served
      for (var i = 0; i < items.length; i++) {
        items[i]['itemStatus'] = 'served';
      }
      servedCount = totalItems;
    } else if (newStatus == 'skipped') {
      // Mark all non-served items as skipped
      for (var i = 0; i < items.length; i++) {
        final current = (items[i]['itemStatus'] as String? ?? 'pending').toLowerCase();
        if (current != 'served') {
          items[i]['itemStatus'] = 'skipped';
        }
      }
    } else if (newStatus == 'partial' && selectedIndices != null) {
      // User requested: mark selected items as served, others as pending
      for (var i = 0; i < items.length; i++) {
        final currentStatus = (items[i]['itemStatus'] as String? ?? 'pending').toLowerCase();
        
        if (selectedIndices.contains(i)) {
          items[i]['itemStatus'] = 'served';
        } else {
          // If it was already served, keep it served. 
          // If it was ready or pending, and NOT selected now, move to pending (per user request)
          if (currentStatus != 'served') {
            items[i]['itemStatus'] = 'pending';
          }
        }
      }
    }

    // ALWAYS recalculate all counts from the items list for correctness
    pendingCount = 0;
    readyCount = 0;
    servedCount = 0;
    skippedCount = 0;
    
    for (var item in items) {
      final s = (item['itemStatus'] as String? ?? 'pending').toLowerCase();
      final qty = (item['quantity'] as int? ?? 1);
      if (s == 'ready') {
        readyCount += qty;
      } else if (s == 'served') {
        servedCount += qty;
      } else if (s == 'skipped') {
        skippedCount += qty;
      } else {
        pendingCount += qty;
      }
    }

    // Determine the final overall status
    // Skip overrides partial — if staff skips, it goes to skipped tab
    String finalStatus = newStatus;
    if (servedCount == totalItems) {
      finalStatus = 'served';
    } else if (servedCount > 0 && newStatus != 'skipped') {
      finalStatus = 'partial';
    }

    final bool wasReady = oldStatus == 'ready';

    // Write BOTH fields so all modules stay synced
    await FirebaseFirestore.instance
        .collection('canteens')
        .doc('default')
        .collection('orders')
        .doc(widget.orderId)
        .update({
          'statusCategory': finalStatus,
          'orderStatus': finalStatus,
          'items': items,
          'pendingItemCount': pendingCount,
          'readyItemCount': readyCount,
          'servedItemCount': servedCount,
          'skippedItemCount': skippedCount,
          'hasPartialItems': finalStatus == 'partial',
          'activeForStaff': (finalStatus != 'served'),
          'readyBeforeSkip': (newStatus == 'skipped') ? wasReady : (widget.order['readyBeforeSkip'] ?? false),
          'isCalledForPickup': (newStatus == 'skipped') ? false : (widget.order['isCalledForPickup'] ?? false),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Add notifications
    final studentId = widget.order['studentId'] ?? widget.order['uid'];
    if (studentId != null) {
      if (finalStatus == 'served') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .collection('notifications')
            .add({
          'title': 'Enjoy Your Meal! 😋',
          'body': 'Token #${widget.order['tokenNumber']} has been served. Thank you!',
          'type': 'order_served',
          'orderId': widget.orderId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      } else if (newStatus == 'skipped') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .collection('notifications')
            .add({
          'title': 'Token Skipped ⏳',
          'body': 'Token #${widget.order['tokenNumber']} was skipped because you were not at the counter. Please wait.',
          'type': 'order_skipped',
          'orderId': widget.orderId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    }
  }
}
