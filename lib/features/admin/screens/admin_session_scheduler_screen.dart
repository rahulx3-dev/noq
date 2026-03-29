import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qcutapp/app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/models/admin_models.dart';
import '../../../app/themes/admin_theme.dart';

class AdminSessionSchedulerScreen extends ConsumerStatefulWidget {
  const AdminSessionSchedulerScreen({super.key});

  @override
  ConsumerState<AdminSessionSchedulerScreen> createState() =>
      _AdminSessionSchedulerScreenState();
}

class _AdminSessionSchedulerScreenState
    extends ConsumerState<AdminSessionSchedulerScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final bgColor = const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.adminDashboard),
                icon: const Icon(Icons.arrow_back, color: AdminTheme.textPrimary),
              ),
              title: Text(
                'Session Scheduler',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              centerTitle: true,
            ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              onPressed: () => _showSessionDialog(null),
              backgroundColor: AdminTheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
      body: sessionsAsync.when(
        data: (sessions) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isDesktop ? 40 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDesktop) _buildDesktopHeader(),
                    const SizedBox(height: 32),
                    _buildStatsRow(sessions, isDesktop),
                    const SizedBox(height: 32),
                    if (sessions.isEmpty)
                      _buildEmptyState()
                    else
                      _buildSessionsGrid(sessions, isDesktop),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdminTheme.primary),
        ),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.adminDashboard),
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          color: AdminTheme.textPrimary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Scheduler',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage operating hours and meal sessions for the canteen.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showSessionDialog(null),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            'Add New Session',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: AdminTheme.primary.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(List<SessionModel> sessions, bool isDesktop) {
    final activeCount = sessions.where((s) => s.isActive).length;
    final inactiveCount = sessions.where((s) => !s.isActive).length;
    final totalCount = sessions.length;

    final cards = [
      _buildStatCard(
        label: 'Active Sessions',
        value: activeCount.toString(),
        icon: Icons.check_circle_rounded,
        iconColor: Colors.green[600]!,
        iconBg: Colors.green[50]!,
      ),
      _buildStatCard(
        label: 'Total Sessions',
        value: totalCount.toString(),
        icon: Icons.schedule_rounded,
        iconColor: Colors.blue[600]!,
        iconBg: Colors.blue[50]!,
      ),
      _buildStatCard(
        label: 'Inactive Sessions',
        value: inactiveCount.toString(),
        icon: Icons.pause_circle_rounded,
        iconColor: Colors.orange[600]!,
        iconBg: Colors.orange[50]!,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 24),
          Expanded(child: cards[1]),
          const SizedBox(width: 24),
          Expanded(child: cards[2]),
        ],
      );
    } else {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 16),
          cards[1],
          const SizedBox(height: 16),
          cards[2],
        ],
      );
    }
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
            ],
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            Text(
              'No sessions scheduled',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first meal session to get started.',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsGrid(List<SessionModel> sessions, bool isDesktop) {
    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          mainAxisExtent: 320,
        ),
        itemCount: sessions.length,
        itemBuilder: (context, index) => _buildSessionCard(sessions[index]),
      );
    } else {
      return Column(
        children: sessions
            .map((session) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildSessionCard(session),
                ))
            .toList(),
      );
    }
  }

  Widget _buildSessionCard(SessionModel session) {
    // Generate some dynamic icon colors based on session order or index pseudo-randomly for aesthetic mapping
    final iconData = Icons.wb_sunny_rounded;
    final iconColor = session.isActive ? Colors.yellow[700]! : Colors.grey[500]!;
    final iconBg = session.isActive ? Colors.yellow[50]! : Colors.grey[100]!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon, Title, Active Switch
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(iconData, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session Order: ${session.order}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.isActive ? Colors.green[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: session.isActive ? Colors.green[200]! : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: session.isActive ? Colors.green[500] : Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            session.isActive ? 'Active' : 'Inactive',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: session.isActive ? Colors.green[700] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: session.isActive,
                onChanged: (v) {
                  ref.read(firestoreServiceProvider).saveSession(
                    'default',
                    session.id,
                    {'isActive': v},
                  );
                },
                activeThumbColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Middle Row: Time Range
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50], // Slightly darker than white
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: Colors.grey[400], size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TIME RANGE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${session.startTime} — ${session.endTime}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AdminTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _showSessionDialog(session),
                  icon: Icon(Icons.edit_rounded, color: Colors.grey[400], size: 20),
                  hoverColor: Colors.grey[200],
                  splashRadius: 20,
                  tooltip: 'Quick Edit Time',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Bottom Row: Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(session),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red[100]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _showSessionDialog(session),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AdminTheme.primary,
                  side: BorderSide(color: Colors.grey[300]!),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Edit Session',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSessionDialog(SessionModel? session) {
    showDialog(
      context: context,
      builder: (context) => _SessionEditDialog(session: session),
    );
  }

  void _confirmDelete(SessionModel session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Session',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${session.name}"? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(firestoreServiceProvider).deleteSession('default', session.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SessionEditDialog extends ConsumerStatefulWidget {
  final SessionModel? session;
  const _SessionEditDialog({this.session});

  @override
  ConsumerState<_SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends ConsumerState<_SessionEditDialog> {
  final _nameController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      _nameController.text = widget.session!.name;
      _startController.text = widget.session!.startTime;
      _endController.text = widget.session!.endTime;
      _orderController.text = widget.session!.order.toString();
      _isActive = widget.session!.isActive;
    } else {
      _orderController.text = '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.session == null ? 'Add Session' : 'Edit Session'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Session Name (e.g. Lunch)',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerField(
                    label: 'Start Time',
                    controller: _startController,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimePickerField(
                    label: 'End Time',
                    controller: _endController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _orderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Display Order'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Is Active'),
                const Spacer(),
                Switch(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeThumbColor: AdminTheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final data = {
              'name': _nameController.text.trim(),
              'startTime': _startController.text.trim(),
              'endTime': _endController.text.trim(),
              'isActive': _isActive,
              'order': int.tryParse(_orderController.text) ?? 0,
            };
            await ref
                .read(firestoreServiceProvider)
                .saveSession('default', widget.session?.id, data);
            if (context.mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TextEditingController controller,
  }) {
    return InkWell(
      onTap: () async {
        final currentStr = controller.text;
        TimeOfDay? initialTime;
        try {
          final formats = ['hh:mm a', 'h:mm a', 'HH:mm', 'H:mm'];
          for (var f in formats) {
            try {
              final dt = DateFormat(f).parse(currentStr);
              initialTime = TimeOfDay.fromDateTime(dt);
              break;
            } catch (_) {}
          }
        } catch (_) {}

        final picked = await showTimePicker(
          context: context,
          initialTime: initialTime ?? const TimeOfDay(hour: 8, minute: 0),
        );

        if (picked != null) {
          if (mounted) {
            setState(() {
              controller.text = picked.format(context);
            });
          }
        }
      },
      child: IgnorePointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.access_time),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    _orderController.dispose();
    super.dispose();
  }
}
