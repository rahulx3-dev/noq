import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qcutapp/app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/models/admin_models.dart';
import '../../../app/themes/admin_theme.dart';

class AdminSlotDefaultsScreen extends ConsumerStatefulWidget {
  const AdminSlotDefaultsScreen({super.key});

  @override
  ConsumerState<AdminSlotDefaultsScreen> createState() =>
      _AdminSlotDefaultsScreenState();
}

class _AdminSlotDefaultsScreenState
    extends ConsumerState<AdminSlotDefaultsScreen> {
  final Map<String, TextEditingController> _intervalControllers = {};
  final Map<String, TextEditingController> _capacityControllers = {};
  final Map<String, List<Map<String, dynamic>>> _customSlots = {};
  bool _isSaving = false;

  @override
  void dispose() {
    for (var c in _intervalControllers.values) {
      c.dispose();
    }
    for (var c in _capacityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll(List<SessionModel> sessions) async {
    setState(() => _isSaving = true);
    try {
      final firestore = ref.read(firestoreServiceProvider);
      for (var session in sessions) {
        final interval =
            int.tryParse(_intervalControllers[session.id]?.text ?? '') ??
            session.defaultInterval;
        final capacity =
            int.tryParse(_capacityControllers[session.id]?.text ?? '') ??
            session.defaultCapacity;

        await firestore.saveSession('default', session.id, {
          'defaultInterval': interval,
          'defaultCapacity': capacity,
          'customSlots': _customSlots[session.id] ?? session.customSlots,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot defaults saved successfully.'),
            backgroundColor: AdminTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving defaults: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
                icon: const Icon(Icons.arrow_back, color: AdminTheme.textPrimary),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.adminDashboard),
              ),
              title: Text(
                'Slot Defaults',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              centerTitle: true,
            ),
      body: sessionsAsync.when(
        data: (sessions) {
          final activeSessions = sessions.where((s) => s.isActive).toList();
          if (activeSessions.isEmpty) {
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 48 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDesktop) _buildDesktopHeader(context),
                    const SizedBox(height: 32),
                    _buildSessionsGrid(activeSessions, isDesktop),
                    const SizedBox(height: 100), // padding for fixed bottom bar
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
      bottomSheet: sessionsAsync.maybeWhen(
        data: (sessions) => sessions.where((s) => s.isActive).isNotEmpty
            ? _buildBottomBar(context, sessions)
            : null,
        orElse: () => null,
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
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
            Row(
              children: [
                Text(
                  'Settings',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Slot Defaults',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AdminTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Slot Defaults',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure default session times, intervals, and capacity',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => context.push('/admin/sessions'),
          icon: const Icon(Icons.schedule_rounded, size: 18),
          label: Text(
            'Session Scheduler',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(
            foregroundColor: AdminTheme.primary,
            backgroundColor: AdminTheme.primary.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, List<SessionModel> sessions) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => context.pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _isSaving ? null : () => _saveAll(sessions),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: AdminTheme.primary.withValues(alpha: 0.3),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ],
        ),
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
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Sessions Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Activate sessions in the Session Scheduler first.',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/admin/sessions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Go to Session Scheduler'),
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
          crossAxisCount: 3,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 0.65, // adjustable depending on height of card
        ),
        itemCount: sessions.length,
        itemBuilder: (context, index) => _buildSessionConfigPanel(sessions[index]),
      );
    } else {
      return Column(
        children: sessions
            .map((session) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildSessionConfigPanel(session),
                ))
            .toList(),
      );
    }
  }

  Widget _buildSessionConfigPanel(SessionModel session) {
    if (!_intervalControllers.containsKey(session.id)) {
      _intervalControllers[session.id] = TextEditingController(
        text: session.defaultInterval.toString(),
      );
      _capacityControllers[session.id] = TextEditingController(
        text: session.defaultCapacity.toString(),
      );
      _customSlots[session.id] = List.from(session.customSlots);
    }

    // Determine colors/icons loosely based on order or name
    IconData icon = Icons.light_mode_rounded;
    Color color = Colors.orange[400]!;
    if (session.name.toLowerCase().contains('lunch')) {
      color = Colors.blue[500]!;
    } else if (session.name.toLowerCase().contains('dinner')) {
      icon = Icons.bedtime_rounded;
      color = Colors.indigo[500]!;
    }

    return Container(
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    session.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Icon(icon, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyTimeField(
                      'START TIME',
                      session.startTime,
                      'Opening hour',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildReadOnlyTimeField(
                      'END TIME',
                      session.endTime,
                      'Closing hour',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInputField(
                'DEFAULT INTERVAL',
                _intervalControllers[session.id]!,
                'min',
                'Time between slots',
              ),
              const SizedBox(height: 20),
              _buildInputField(
                'DEFAULT CAPACITY',
                _capacityControllers[session.id]!,
                'orders',
                'Max orders per slot',
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(height: 1),
          const SizedBox(height: 24),
          _buildCustomSlotsSection(session),
        ],
      ),
    );
  }

  Widget _buildReadOnlyTimeField(String label, String value, String helper) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500], // grey text to look disabled
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String suffix,
    String helper,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AdminTheme.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 16, top: 14),
              child: Text(
                suffix,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AdminTheme.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildCustomSlotsSection(SessionModel session) {
    final slots = _customSlots[session.id] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Custom Slots',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textPrimary,
              ),
            ),
            InkWell(
              onTap: () => _showAddCustomSlotDialog(session),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 14, color: AdminTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (slots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              'No custom slots added.\nUsing interval-based generation.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${slot['startTime']} — ${slot['endTime']} (${slot['capacity']})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _customSlots[session.id]?.remove(slot);
                        });
                      },
                      child: Icon(Icons.close, size: 14, color: Colors.blue[800]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showAddCustomSlotDialog(SessionModel session) {
    final startController = TextEditingController();
    final endController = TextEditingController();
    final capController = TextEditingController(
      text: session.defaultCapacity.toString(),
    );

    void updateTime(TextEditingController controller) async {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        if (mounted) controller.text = time.format(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Add Custom Slot: ${session.name}',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTimeField(
                'Start Time',
                startController,
                () => updateTime(startController),
              ),
              const SizedBox(height: 16),
              _buildDialogTimeField(
                'End Time',
                endController,
                () => updateTime(endController),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: capController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.plusJakartaSans(),
                decoration: InputDecoration(
                  labelText: 'Max Orders (Capacity)',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                if (startController.text.isNotEmpty && endController.text.isNotEmpty) {
                  setState(() {
                    _customSlots[session.id] ??= [];
                    _customSlots[session.id]!.add({
                      'startTime': startController.text,
                      'endTime': endController.text,
                      'capacity': int.tryParse(capController.text) ?? 5,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Add Slot', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTimeField(
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.text.isEmpty ? 'Select Time' : controller.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: controller.text.isEmpty ? Colors.grey[400] : AdminTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.access_time_rounded, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
