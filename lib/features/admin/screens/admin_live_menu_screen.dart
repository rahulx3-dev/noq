import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:qcutapp/core/providers.dart';
import 'package:qcutapp/core/models/admin_models.dart';
import 'package:qcutapp/app/themes/admin_theme.dart';
import 'package:qcutapp/core/widgets/app_motion_widgets.dart';
import 'package:qcutapp/app/app_routes.dart';
import 'package:qcutapp/core/utils/time_helper.dart';

class AdminLiveMenuScreen extends ConsumerStatefulWidget {
  const AdminLiveMenuScreen({super.key});

  @override
  ConsumerState<AdminLiveMenuScreen> createState() =>
      _AdminLiveMenuScreenState();
}

class _AdminLiveMenuScreenState extends ConsumerState<AdminLiveMenuScreen> {
  final DateTime _selectedDate = DateTime.now();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Buffered changes — using composite keys: "sessionId|itemId" or "sessionId|slotId"
  final Map<String, bool> _pendingAvailability = {};
  final Map<String, int> _pendingStocks = {};
  final Map<String, int> _pendingCapacities = {};
  final Set<String> _pendingDeletions = {};
  // For new items added via modal — each map must include 'sessionId'
  final List<Map<String, dynamic>> _pendingAdditions = [];

  // Session-level overrides
  final Map<String, String> _pendingSessionEndTimes = {};
  final Map<String, int> _pendingSessionIntervals = {};
  final Map<String, int> _pendingSessionCapacities = {};

  bool get _hasChanges =>
      _pendingAvailability.isNotEmpty ||
      _pendingStocks.isNotEmpty ||
      _pendingCapacities.isNotEmpty ||
      _pendingDeletions.isNotEmpty ||
      _pendingAdditions.isNotEmpty ||
      _pendingSessionEndTimes.isNotEmpty ||
      _pendingSessionIntervals.isNotEmpty ||
      _pendingSessionCapacities.isNotEmpty;

  void _clearChanges() {
    setState(() {
      _pendingAvailability.clear();
      _pendingStocks.clear();
      _pendingCapacities.clear();
      _pendingDeletions.clear();
      _pendingAdditions.clear();
      _pendingSessionEndTimes.clear();
      _pendingSessionIntervals.clear();
      _pendingSessionCapacities.clear();
    });
  }

  Future<void> _applyChanges() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Apply Changes?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to apply all pending modifications to the live menu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primary,
            ),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final canteenId = 'default';

      // Helper to parse composite keys
      DocumentReference itemRef(String compositeKey) {
        final parts = compositeKey.split('|');
        final sessionId = parts[0];
        final itemId = parts[1];
        return FirebaseFirestore.instance
            .collection('canteens')
            .doc(canteenId)
            .collection('dailyMenus')
            .doc(dateStr)
            .collection('sessions')
            .doc(sessionId)
            .collection('items')
            .doc(itemId);
      }

      DocumentReference slotRef(String compositeKey) {
        final parts = compositeKey.split('|');
        final sessionId = parts[0];
        final slotId = parts[1];
        return FirebaseFirestore.instance
            .collection('canteens')
            .doc(canteenId)
            .collection('dailyMenus')
            .doc(dateStr)
            .collection('sessions')
            .doc(sessionId)
            .collection('slots')
            .doc(slotId);
      }

      // 1. Availability updates
      _pendingAvailability.forEach((key, val) {
        batch.update(itemRef(key), {'isAvailableSnapshot': val});
      });

      // 2. Stock updates
      _pendingStocks.forEach((key, val) {
        batch.update(itemRef(key), {'remainingStock': val});
      });

      // 3. Capacity updates
      _pendingCapacities.forEach((key, val) {
        batch.update(slotRef(key), {'capacity': val});
      });

      // 4. Deletions
      for (var key in _pendingDeletions) {
        batch.delete(itemRef(key));
      }

      // 5. Additions
      for (var item in _pendingAdditions) {
        final sessionId = item['sessionId'] as String;
        final ref = FirebaseFirestore.instance
            .collection('canteens')
            .doc(canteenId)
            .collection('dailyMenus')
            .doc(dateStr)
            .collection('sessions')
            .doc(sessionId)
            .collection('items')
            .doc();

        final data = Map<String, dynamic>.from(item);
        data.remove(
          'sessionId',
        ); // Don't store sessionId inside the doc if not needed, or keep it.
        batch.set(ref, data);
      }

      // 6. Session-level updates
      final sessionIdsToSync = <String>{
        ..._pendingSessionEndTimes.keys,
        ..._pendingSessionIntervals.keys,
        ..._pendingSessionCapacities.keys,
      };

      for (var sessionId in sessionIdsToSync) {
        final sessionRef = FirebaseFirestore.instance
            .collection('canteens')
            .doc(canteenId)
            .collection('dailyMenus')
            .doc(dateStr)
            .collection('sessions')
            .doc(sessionId);

        final sessUpdates = <String, dynamic>{};
        if (_pendingSessionEndTimes.containsKey(sessionId)) {
          sessUpdates['endTime'] = _pendingSessionEndTimes[sessionId];
        }
        if (_pendingSessionIntervals.containsKey(sessionId)) {
          sessUpdates['slotInterval'] = _pendingSessionIntervals[sessionId];
        }
        if (_pendingSessionCapacities.containsKey(sessionId)) {
          sessUpdates['slotCapacity'] = _pendingSessionCapacities[sessionId];
        }

        if (sessUpdates.isNotEmpty) {
          batch.update(sessionRef, sessUpdates);
        }

        // Handle bulk capacity update for all slots in this session
        if (_pendingSessionCapacities.containsKey(sessionId)) {
          final newCap = _pendingSessionCapacities[sessionId]!;
          final slotsSnap = await sessionRef.collection('slots').get();
          for (var sDoc in slotsSnap.docs) {
            final data = sDoc.data();
            final oldCap = data['capacity'] as int? ?? 0;
            final oldRem = data['remainingCapacity'] as int? ?? 0;
            final consumed = oldCap - oldRem;
            batch.update(sDoc.reference, {
              'capacity': newCap,
              'remainingCapacity': (newCap - consumed).clamp(0, newCap),
            });
          }
        }
      }

      await batch.commit();
      _clearChanges();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes applied successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error applying changes: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final releasedSessionsAsync = ref.watch(releasedSessionsProvider(dateStr));
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AdminTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go(AppRoutes.adminDashboard),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search items...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() {}),
              )
            : Text(
                'Live Menu Management',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black54),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black54),
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: releasedSessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isDesktop ? 32 : 20),
              child: Column(
                children: [_buildTopBanner(context, false), _buildEmptyState()],
              ),
            );
          }

          // ── Split sessions by operational state ──────────────────────────
          final liveSessions = sessions
              .where((s) => s['timeState'] == 'current')
              .toList();
          final upcomingSessions = sessions
              .where((s) => s['timeState'] == 'upcoming')
              .toList();
          final endedSessions = sessions
              .where((s) => s['timeState'] == 'ended')
              .toList();

          final bool hasAnythingLive = liveSessions.isNotEmpty;

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 20,
                  isDesktop ? 20 : 0,
                  isDesktop ? 32 : 20,
                  120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBanner(context, hasAnythingLive),
                    const SizedBox(height: 24),

                    // ── LIVE sessions ─────────────────────────────────────
                    if (liveSessions.isNotEmpty) ...[
                      _buildSectionHeader(
                        label: 'LIVE NOW',
                        badge: const _LiveBadge(),
                        description:
                            'Active sessions — changes apply immediately.',
                      ),
                      const SizedBox(height: 12),
                      ...liveSessions.map(
                        (session) => _buildSessionTile(
                          context: context,
                          session: session,
                          dateStr: dateStr,
                          isEditable: true,
                        ),
                      ),
                    ],

                    // ── UPCOMING sessions ─────────────────────────────────
                    if (upcomingSessions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        label: 'UPCOMING',
                        badge: const _UpcomingBadge(),
                        description: 'Not started yet. Pre-stage availability.',
                      ),
                      const SizedBox(height: 12),
                      ...upcomingSessions.map(
                        (session) => _buildSessionTile(
                          context: context,
                          session: session,
                          dateStr: dateStr,
                          isEditable: true,
                        ),
                      ),
                    ],

                    // ── ENDED sessions (read-only, clearly labelled) ──────
                    if (endedSessions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        label: 'ENDED — READ ONLY',
                        badge: const _EndedBadge(),
                        description:
                            'These sessions have ended. Shown for reference only.',
                      ),
                      const SizedBox(height: 12),
                      ...endedSessions.map(
                        (session) => Opacity(
                          opacity: 0.65,
                          child: _buildSessionTile(
                            context: context,
                            session: session,
                            dateStr: dateStr,
                            isEditable: false,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Apply Changes button ──────
              if (_hasChanges)
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: AppFadeSlide(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(51),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _applyChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline),
                            const SizedBox(width: 12),
                            Text(
                              'CONFIRM CHANGES',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildTopBanner(BuildContext context, bool isLive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showAddItemModal(context, ref),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Item to Live Menu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: AdminTheme.primary.withAlpha(102),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLive ? 'Live Menu' : 'Released Menu',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
              isLive ? const _LiveBadge() : const _NoActiveBadge(),
            ],
          ),
          if (!isLive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No session is running right now. Released sessions shown below.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AdminTheme.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String label,
    required Widget badge,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AdminTheme.textPrimary,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AdminTheme.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTile({
    required BuildContext context,
    required Map<String, dynamic> session,
    required String dateStr,
    required bool isEditable,
  }) {
    final sessionId = session['sessionId'] as String;
    final sessionName = session['name'] as String? ?? sessionId;
    final timeState = session['timeState'] as String? ?? 'ended';

    Color titleColor;
    if (timeState == 'current') {
      titleColor = const Color(0xFF1E8E3E);
    } else if (timeState == 'upcoming') {
      titleColor = AdminTheme.primary;
    } else {
      titleColor = AdminTheme.textSecondary;
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: ExpansionTile(
          initiallyExpanded: timeState == 'current',
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Text(
            sessionName.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: titleColor,
              letterSpacing: 1.2,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                '${session['startTime']} – ${session['endTime']}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AdminTheme.textPrimary.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              if (isEditable)
                TextButton.icon(
                  onPressed: () {
                    final dateStr = DateFormat(
                      'yyyy-MM-dd',
                    ).format(_selectedDate);
                    _showCapacityAdjustmentPopup(
                      context,
                      ref,
                      dateStr,
                      sessionId,
                      sessionName,
                    );
                  },
                  icon: const Icon(
                    Icons.confirmation_number_outlined,
                    size: 14,
                  ),
                  label: const Text('Slots & Capacity'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: titleColor,
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          children: [
            if (isEditable)
              _buildSessionSettingsRow(context, sessionId, session),
            IgnorePointer(
              ignoring: !isEditable,
              child: _SessionLiveItemsList(
                date: dateStr,
                sessionId: sessionId,
                sessionName: sessionName,
                // Filter pending maps for this session
                pendingAvailability: _filterMapBySessionId(
                  _pendingAvailability,
                  sessionId,
                ),
                pendingStocks: _filterMapBySessionId(_pendingStocks, sessionId),
                pendingCapacities: _filterMapBySessionId(
                  _pendingCapacities,
                  sessionId,
                ),
                pendingDeletions: _filterSetBySessionId(
                  _pendingDeletions,
                  sessionId,
                ),

                onAvailabilityChanged: (id, val) => setState(
                  () => _pendingAvailability['$sessionId|$id'] = val,
                ),
                onStockChanged: (id, val) =>
                    setState(() => _pendingStocks['$sessionId|$id'] = val),
                onCapacityChanged: (id, val) =>
                    setState(() => _pendingCapacities['$sessionId|$id'] = val),
                onDelete: (id) =>
                    setState(() => _pendingDeletions.add('$sessionId|$id')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, T> _filterMapBySessionId<T>(
    Map<String, T> original,
    String sessionId,
  ) {
    final Map<String, T> filtered = {};
    original.forEach((key, value) {
      if (key.startsWith('$sessionId|')) {
        filtered[key.split('|')[1]] = value;
      }
    });
    return filtered;
  }

  Set<String> _filterSetBySessionId(Set<String> original, String sessionId) {
    return original
        .where((key) => key.startsWith('$sessionId|'))
        .map((key) => key.split('|')[1])
        .toSet();
  }

  Widget _buildSessionSettingsRow(
    BuildContext context,
    String sessionId,
    Map<String, dynamic> session,
  ) {
    final originalEndTime = session['endTime'] as String? ?? '';
    final originalInterval = session['slotInterval'] as int? ?? 15;
    final originalCapacity = session['slotCapacity'] as int? ?? 20;

    final currentEndTime =
        _pendingSessionEndTimes[sessionId] ?? originalEndTime;
    final currentInterval =
        _pendingSessionIntervals[sessionId] ?? originalInterval;
    final currentCapacity =
        _pendingSessionCapacities[sessionId] ?? originalCapacity;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AdminTheme.primary.withAlpha(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SESSION CONFIGURATION',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AdminTheme.textPrimary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSessionSettingField(
                  label: 'End Time',
                  value: currentEndTime,
                  icon: Icons.access_time,
                  onTap: () async {
                    final parsed = TimeHelper.parseSessionTime(
                      currentEndTime,
                      _selectedDate,
                    );
                    final initialTime = parsed != null
                        ? TimeOfDay(hour: parsed.hour, minute: parsed.minute)
                        : const TimeOfDay(hour: 12, minute: 0);

                    final picked = await showTimePicker(
                      context: context,
                      initialTime: initialTime,
                    );
                    if (picked != null) {
                      final now = DateTime.now();
                      final dt = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        picked.hour,
                        picked.minute,
                      );
                      final val = DateFormat('hh:mm a').format(dt);
                      setState(() => _pendingSessionEndTimes[sessionId] = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSessionSettingField(
                  label: 'Interval',
                  value: '$currentInterval m',
                  icon: Icons.timer_outlined,
                  onTap: () => _showSessionSettingDialog(
                    context,
                    'Edit Interval (min)',
                    currentInterval.toString(),
                    (val) => setState(
                      () =>
                          _pendingSessionIntervals[sessionId] = int.parse(val),
                    ),
                    isNumeric: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSessionSettingField(
                  label: 'Capacity',
                  value: '$currentCapacity',
                  icon: Icons.people_outline,
                  onTap: () => _showSessionSettingDialog(
                    context,
                    'Bulk Capacity',
                    currentCapacity.toString(),
                    (val) => setState(
                      () =>
                          _pendingSessionCapacities[sessionId] = int.parse(val),
                    ),
                    isNumeric: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSettingField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 10, color: AdminTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionSettingDialog(
    BuildContext context,
    String title,
    String initialValue,
    Function(String) onSave, {
    bool isNumeric = false,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          autofocus: true,
          decoration: AdminTheme.inputDecoration(
            hint: 'Enter value',
            label: title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primary,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showAddItemModal(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final sessionsAsync = ref.read(releasedSessionsProvider(dateStr));

    if (sessionsAsync.value == null || sessionsAsync.value!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No released sessions today. Please release a session first.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddItemModal(
        date: dateStr,
        sessions: sessionsAsync.value!,
        onItemsAdded: (items) {
          setState(() => _pendingAdditions.addAll(items));
        },
      ),
    );
  }

  void _showCapacityAdjustmentPopup(
    BuildContext context,
    WidgetRef ref,
    String dateStr,
    String sessionId,
    String sessionName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _CapacityAdjustmentPopup(
        date: dateStr,
        sessionId: sessionId,
        sessionName: sessionName,
        pendingCapacities: _pendingCapacities,
        onCapacityChanged: (slotId, newVal) {
          setState(() {
            _pendingCapacities['$sessionId|$slotId'] = newVal;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              'No released sessions for today',
              style: GoogleFonts.plusJakartaSans(
                color: AdminTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionLiveItemsList extends ConsumerWidget {
  final String date;
  final String sessionId;
  final String sessionName;
  final Map<String, bool> pendingAvailability;
  final Map<String, int> pendingStocks;
  final Map<String, int> pendingCapacities;
  final Set<String> pendingDeletions;
  final Function(String, bool) onAvailabilityChanged;
  final Function(String, int) onStockChanged;
  final Function(String, int) onCapacityChanged;
  final Function(String) onDelete;

  const _SessionLiveItemsList({
    required this.date,
    required this.sessionId,
    required this.sessionName,
    required this.pendingAvailability,
    required this.pendingStocks,
    required this.pendingCapacities,
    required this.pendingDeletions,
    required this.onAvailabilityChanged,
    required this.onStockChanged,
    required this.onCapacityChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(
      sessionItemsStreamProvider((date: date, sessionId: sessionId)),
    );
    final slotsAsync = ref.watch(
      sessionSlotsStreamProvider((date: date, sessionId: sessionId)),
    );

    return itemsAsync.when(
      data: (snapshot) {
        final items = snapshot.docs;
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No items in this session.',
              style: GoogleFonts.plusJakartaSans(
                color: AdminTheme.textPrimary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          children: [
            // Slots Mini-Grid
            slotsAsync.when(
              data: (snap) =>
                  const SizedBox.shrink(), // Hiding mini-grid in favor of popup
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: Colors.grey[100]),
              itemBuilder: (context, index) {
                final doc = items[index];
                final itemId = doc.id;
                final data = doc.data();

                if (pendingDeletions.contains(itemId)) {
                  return const SizedBox.shrink();
                }

                return _LiveItemCard(
                  key: ValueKey(itemId),
                  itemId: itemId,
                  data: data,
                  pendingAvailability: pendingAvailability[itemId],
                  pendingStock: pendingStocks[itemId],
                  onAvailabilityChanged: (val) =>
                      onAvailabilityChanged(itemId, val),
                  onStockChanged: (val) => onStockChanged(itemId, val),
                  onDelete: () => onDelete(itemId),
                );
              },
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text('Error loading items: $e'),
      ),
    );
  }
}

class _CapacityAdjustmentPopup extends ConsumerStatefulWidget {
  final String date;
  final String sessionId;
  final String sessionName;
  final Map<String, int> pendingCapacities;
  final Function(String, int) onCapacityChanged;

  const _CapacityAdjustmentPopup({
    required this.date,
    required this.sessionId,
    required this.sessionName,
    required this.pendingCapacities,
    required this.onCapacityChanged,
  });

  @override
  ConsumerState<_CapacityAdjustmentPopup> createState() =>
      _CapacityAdjustmentPopupState();
}

class _CapacityAdjustmentPopupState
    extends ConsumerState<_CapacityAdjustmentPopup> {
  final Map<String, int> _localCapacities = {};

  @override
  void initState() {
    super.initState();
    // Initialize local state from parent
    widget.pendingCapacities.forEach((key, value) {
      if (key.startsWith('${widget.sessionId}|')) {
        _localCapacities[key.split('|')[1]] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(
      sessionSlotsStreamProvider((
        date: widget.date,
        sessionId: widget.sessionId,
      )),
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adjust Slot Capacity',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            widget.sessionName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AdminTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: slotsAsync.when(
          data: (snap) {
            final docs = snap.docs;
            return ListView.separated(
              shrinkWrap: true,
              itemCount: docs.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final slotId = doc.id;
                final data = doc.data();
                final dbCapacity = data['capacity'] as int? ?? 0;
                final dbRemaining = data['remainingCapacity'] as int? ?? 0;

                // Consumption is total - remaining
                final consumed = dbCapacity - dbRemaining;

                final currentCapacity = _localCapacities[slotId] ?? dbCapacity;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${data['startTime']} - ${data['endTime']}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Consumed: $consumed',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AdminTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CircularButton(
                            icon: Icons.remove,
                            onPressed: currentCapacity > consumed
                                ? () => setState(() {
                                    _localCapacities[slotId] =
                                        currentCapacity - 1;
                                  })
                                : null,
                          ),
                          Container(
                            width: 50,
                            alignment: Alignment.center,
                            child: Text(
                              '$currentCapacity',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AdminTheme.primary,
                              ),
                            ),
                          ),
                          _CircularButton(
                            icon: Icons.add,
                            onPressed: () => setState(() {
                              _localCapacities[slotId] = currentCapacity + 1;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () {
            _localCapacities.forEach((slotId, val) {
              widget.onCapacityChanged(slotId, val);
            });
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('CONFIRM'),
        ),
      ],
    );
  }
}

class _CircularButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CircularButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onPressed == null
            ? Colors.grey[100]
            : AdminTheme.primary.withAlpha(20),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        color: onPressed == null ? Colors.grey[300] : AdminTheme.primary,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _LiveItemCard extends StatelessWidget {
  final String itemId;
  final Map<String, dynamic> data;
  final bool? pendingAvailability;
  final int? pendingStock;
  final Function(bool) onAvailabilityChanged;
  final Function(int) onStockChanged;
  final VoidCallback onDelete;

  const _LiveItemCard({
    super.key,
    required this.itemId,
    required this.data,
    this.pendingAvailability,
    this.pendingStock,
    required this.onAvailabilityChanged,
    required this.onStockChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['nameSnapshot'] ?? 'Unknown';
    final currentAvailability =
        pendingAvailability ?? (data['isAvailableSnapshot'] ?? true);
    final currentStock = pendingStock ?? (data['remainingStock'] ?? 0);
    final initialStock = data['initialStock'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Image placeholder or real image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  (data['imageUrlSnapshot'] != null &&
                      (data['imageUrlSnapshot'] as String).isNotEmpty)
                  ? Image.network(data['imageUrlSnapshot'], fit: BoxFit.cover)
                  : Icon(Icons.fastfood, color: Colors.grey[300]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'INITIAL: $initialStock',
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminTheme.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Stock Stepper
          AppQuantityStepper(
            quantity: currentStock,
            onIncrement: () => onStockChanged(currentStock + 1),
            onDecrement: () =>
                onStockChanged(currentStock > 0 ? currentStock - 1 : 0),
          ),

          const SizedBox(width: 16),

          // Availability Switch
          Switch(
            value: currentAvailability,
            onChanged: onAvailabilityChanged,
            activeThumbColor: AdminTheme.success,
          ),

          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () {
              // Confirm delete logic could go here
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}

class _AddItemModal extends ConsumerStatefulWidget {
  final String date;
  final List<Map<String, dynamic>> sessions;
  final Function(List<Map<String, dynamic>>) onItemsAdded;

  const _AddItemModal({
    required this.date,
    required this.sessions,
    required this.onItemsAdded,
  });

  @override
  ConsumerState<_AddItemModal> createState() => _AddItemModalState();
}

class _AddItemModalState extends ConsumerState<_AddItemModal> {
  String? _selectedSessionId;
  final Set<String> _selectedItemIds = {};
  final Map<String, int> _itemStocks = {};
  String _itemSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedSessionId = (widget.sessions.isNotEmpty
        ? widget.sessions.first['sessionId']
        : null);
  }

  @override
  Widget build(BuildContext context) {
    final globalMenuItemsAsync = ref.watch(menuItemsStreamProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          _buildSearch(),
          _buildSessionSelector(),
          Expanded(child: _buildItemsList(globalMenuItemsAsync)),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Add to Live Menu',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextField(
        onChanged: (v) => setState(() => _itemSearchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search global menu...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: widget.sessions.map((s) {
          final isSelected = _selectedSessionId == s['sessionId'];
          return GestureDetector(
            onTap: () => setState(() => _selectedSessionId = s['sessionId']),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AdminTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AdminTheme.primary : Colors.grey[200]!,
                ),
              ),
              child: Text(
                (s['name'] as String).toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AdminTheme.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemsList(AsyncValue<List<MenuItemModel>> asyncItems) {
    return asyncItems.when(
      data: (items) {
        final filtered = items
            .where((it) => it.name.toLowerCase().contains(_itemSearchQuery))
            .toList();
        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: Colors.grey[100]),
          itemBuilder: (context, index) {
            final item = filtered[index];
            final isAdded = _selectedItemIds.contains(item.id);
            final stock = _itemStocks[item.id] ?? 20;

            return ListTile(
              leading: Checkbox(
                value: isAdded,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedItemIds.add(item.id);
                      _itemStocks[item.id] = stock;
                    } else {
                      _selectedItemIds.remove(item.id);
                    }
                  });
                },
                activeColor: AdminTheme.primary,
              ),
              title: Text(
                item.name,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '\$${item.price.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(color: AdminTheme.primary),
              ),
              trailing: isAdded
                  ? AppQuantityStepper(
                      quantity: stock,
                      onIncrement: () =>
                          setState(() => _itemStocks[item.id] = stock + 1),
                      onDecrement: () => setState(
                        () => _itemStocks[item.id] = stock > 0 ? stock - 1 : 0,
                      ),
                    )
                  : null,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _selectedItemIds.isEmpty
              ? null
              : () {
                  final List<Map<String, dynamic>> results = [];
                  final items = ref.read(menuItemsStreamProvider).value ?? [];

                  for (var sid in _selectedItemIds) {
                    final model = items.firstWhere((it) => it.id == sid);
                    results.add({
                      'sessionId': _selectedSessionId,
                      'menuItemId': model.id,
                      'nameSnapshot': model.name,
                      'priceSnapshot': model.price,
                      'categoryIdSnapshot': model.categoryId,
                      'imageUrlSnapshot': model.imageUrl,
                      'isAvailableSnapshot': true,
                      'initialStock': _itemStocks[sid] ?? 20,
                      'remainingStock': _itemStocks[sid] ?? 20,
                    });
                  }
                  widget.onItemsAdded(results);
                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'ADD ${_selectedItemIds.length} ITEMS',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1E8E3E),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E8E3E),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingBadge extends StatelessWidget {
  const _UpcomingBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AdminTheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'UPCOMING',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AdminTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedBadge extends StatelessWidget {
  const _EndedBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'ENDED',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveBadge extends StatelessWidget {
  const _NoActiveBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'NO ACTIVE SESSION',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.orange[800],
        ),
      ),
    );
  }
}
