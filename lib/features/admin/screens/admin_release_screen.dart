import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qcutapp/core/providers.dart';
import 'package:qcutapp/core/models/admin_models.dart';
import 'package:qcutapp/core/utils/slot_helper.dart';
import 'package:qcutapp/core/utils/session_status_resolver.dart';
import 'package:qcutapp/app/themes/admin_theme.dart';
import 'package:qcutapp/core/widgets/app_motion_widgets.dart';
import 'package:qcutapp/app/app_routes.dart';

class AdminReleaseScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  const AdminReleaseScreen({super.key, this.initialDate});

  @override
  ConsumerState<AdminReleaseScreen> createState() => _AdminReleaseScreenState();
}

class _AdminReleaseScreenState extends ConsumerState<AdminReleaseScreen> {
  late DateTime _selectedDate;
  bool _isFullDayMode = false;
  bool _isReleasing = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    // Normalize to date only
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
  }

  final Map<String, _SessionDraft> _drafts = {};
  final Set<String> _selectedSessionIds = {};
  String _mainSearchQuery = '';
  String _itemSearchQuery = '';

  void _initializeDrafts(
    List<SessionModel> sessions,
    List<Map<String, dynamic>> releasedSessions,
    List<MenuItemModel> allItems, // Added
  ) {
    for (var session in sessions) {
      if (!_drafts.containsKey(session.id)) {
        final released = releasedSessions.firstWhere(
          (rs) => rs['sessionId'] == session.id,
          orElse: () => {},
        );
        final draft = _SessionDraft.fromModel(session, released);
        
        // Auto-populate global items for NEW drafts (not already released)
        if (released.isEmpty) {
          final globalItems = allItems.where((it) => it.isGlobal).toList();
          for (var gi in globalItems) {
            if (!draft.items.any((id) => id.item.id == gi.id)) {
              draft.items.add(_ItemDraft(item: gi, stock: 99)); // Default stock for global items
            }
          }
        }
        
        _drafts[session.id] = draft;
      }
    }

    if (_selectedSessionIds.isEmpty) {
      final releasedIds = releasedSessions
          .map((s) => s['sessionId'] as String)
          .toSet();

      final available = sessions.where((s) {
        return !_isSessionPast(s) && !releasedIds.contains(s.id);
      }).toList();

      if (_isFullDayMode) {
        _selectedSessionIds.addAll(available.map((s) => s.id));
      } else if (available.isNotEmpty) {
        // Only suggest first if nothing is selected
        _selectedSessionIds.add(available.first.id);
      }
    }
  }

  Future<void> _selectTime(String sessionId, bool isStart) async {
    final draft = _drafts[sessionId]!;
    final initialTimeStr = isStart
        ? draft.session.startTime
        : draft.session.endTime;

    DateTime initialTime;
    try {
      initialTime = DateFormat('hh:mm a').parse(initialTimeStr);
    } catch (_) {
      initialTime = DateFormat('HH:mm').parse(initialTimeStr);
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialTime.hour,
        minute: initialTime.minute,
      ),
    );

    if (picked != null) {
      final newTimeStr = DateFormat(
        'hh:mm a',
      ).format(DateTime(2000, 1, 1, picked.hour, picked.minute));
      setState(() {
        if (isStart) {
          draft.session = draft.session.copyWith(startTime: newTimeStr);
        } else {
          draft.session = draft.session.copyWith(endTime: newTimeStr);
        }
        _updateSlots(sessionId);
      });
    }
  }

  Future<void> _editNumeric(
    String sessionId,
    String title,
    int initialValue,
    bool isInterval,
  ) async {
    final controller = TextEditingController(text: initialValue.toString());
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: isInterval ? 'minutes' : ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (picked != null && picked > 0) {
      setState(() {
        final draft = _drafts[sessionId]!;
        if (isInterval) {
          draft.session = draft.session.copyWith(defaultInterval: picked);
        } else {
          draft.session = draft.session.copyWith(defaultCapacity: picked);
        }
        _updateSlots(sessionId);
      });
    }
  }

  Future<void> _editItemStock(_ItemDraft it) async {
    final controller = TextEditingController(text: it.stock.toString());
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (picked != null && picked >= 0) {
      setState(() {
        it.stock = picked;
      });
    }
  }

  void _updateSlots(String sessionId) {
    setState(() {
      final draft = _drafts[sessionId];
      if (draft == null) return;

      final start = draft.session.startTime;
      final end = draft.session.endTime;
      final interval = draft.session.defaultInterval;
      final cap = draft.session.defaultCapacity;

      if (start.isNotEmpty && end.isNotEmpty && interval > 0 && cap > 0) {
        draft.slots = SlotHelper.generateSlots(
          startTimeStr: start,
          endTimeStr: end,
          intervalMinutes: interval,
          capacity: cap,
          targetDate: _selectedDate,
          customSlots: draft.session.customSlots,
          shouldStartFromNow: true,
        );
      } else {
        draft.slots = [];
      }
    });
  }

  void _editSlotCapacity(_SessionDraft draft, int index) {
    final s = draft.slots[index];
    final controller = TextEditingController(text: s['capacity'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Slot Capacity',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Capacity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCap = int.tryParse(controller.text) ?? s['capacity'];
              setState(() {
                s['capacity'] = newCap;
                s['remainingCapacity'] = newCap; // Sync remaining capacity
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndReleaseMenu() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Release',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to release this menu? Once released, students can start ordering.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primary,
            ),
            child: const Text('Release Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeRelease();
    }
  }

  Future<void> _executeRelease() async {
    setState(() => _isReleasing = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final List<Map<String, dynamic>> sessionsToRelease = [];

      for (var sessionId in _selectedSessionIds) {
        final draft = _drafts[sessionId];
        if (draft == null) continue;

        if (draft.items.isEmpty) {
          throw 'Please add items to "${draft.session.name}" before releasing.';
        }

        final selectedSlots = draft.slots
            .where((s) => s['isSelected'] == true && s['isPast'] != true)
            .toList();

        if (selectedSlots.isEmpty) {
          throw 'Please select at least one time slot for "${draft.session.name}".';
        }

        sessionsToRelease.add({
          'sessionId': draft.session.id,
          'name': draft.session.name,
          'startTime': draft.session.startTime,
          'endTime': draft.session.endTime,
          'slotInterval': draft.interval,
          'slotCapacity': draft.capacity,
          'items': draft.items
              .map(
                (it) => ({
                  'menuItemId': it.item.id,
                  'name': it.item.name,
                  'price': it.item.price,
                  'categoryId': it.item.categoryId,
                  'initialStock': it.stock,
                  'remainingStock': it.stock,
                  'imageUrl': it.item.imageUrl,
                  'isPreReady': it.item.isPreReady,
                }),
              )
              .toList(),
          'slots': selectedSlots
              .map(
                (s) => ({
                  'id': s['id'],
                  'startTime': s['startTime'],
                  'endTime': s['endTime'],
                  'capacity': s['capacity'],
                  'remainingCapacity': s['remainingCapacity'],
                }),
              )
              .toList(),
        });
      }

      if (sessionsToRelease.isEmpty) {
        throw 'No sessions selected for release.';
      }

      final uniqueMenuItemIds = <String>{};
      for (var d in _drafts.values) {
        for (var it in d.items) {
          uniqueMenuItemIds.add(it.item.id);
        }
      }

      await ref.read(firestoreServiceProvider).releaseDailyMenu(
        canteenId: 'default',
        date: dateStr,
        menuData: {
          'date': dateStr,
          'releaseMode': _isFullDayMode ? 'fullDay' : 'session',
          'status': 'released',
          'totalUniqueItems': uniqueMenuItemIds.length,
          'totalSessionsReleased': sessionsToRelease.length,
        },
        sessions: sessionsToRelease,
        createdByUid: widget.initialDate != null
            ? FirebaseAuth.instance.currentUser?.uid
            : FirebaseAuth.instance.currentUser?.uid,
      );

      ref.invalidate(dailyMenuStatusProvider(dateStr));
      if (mounted) {
        setState(() {
          _selectedSessionIds.clear();
        });
        _showSuccessPopup();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Release failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReleasing = false);
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F4EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF1E8E3E),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Menu Released Successfully!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Today\'s menu is now live for all students.',
                style: GoogleFonts.plusJakartaSans(color: AdminTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final itemsAsync = ref.watch(menuItemsStreamProvider);
    final releasedAsync = ref.watch(releasedSessionsProvider(dateStr));

    final isDesktop = MediaQuery.of(context).size.width > 1100;

    return Scaffold(
      backgroundColor: AdminTheme.background,
      appBar: _buildAppBar(isDesktop),
      body: sessionsAsync.when(
        data: (sessions) {
          final activeSessions = sessions.where((s) => s.isActive).toList();
          final releasedSessions = releasedAsync.value ?? [];
          
          return itemsAsync.when(
            data: (allItems) {
              _initializeDrafts(activeSessions, releasedSessions, allItems);
              return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isDesktop) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'noq',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -3.0,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMainConfig(
                                activeSessions,
                                allItems,
                                isDesktop,
                                releasedSessions,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDesktop) _buildRightSummaryPanel(),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        );
      },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDesktop) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => context.go(AppRoutes.adminDashboard),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Release Daily Menu',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            'Admin Configuration Dashboard',
            style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
      actions: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AdminTheme.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Center(
          child: Text(
            'System Online',
            style: GoogleFonts.plusJakartaSans(
              color: AdminTheme.success,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 24),
        _buildDatePicker(),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AdminTheme.primary,
                  onPrimary: Colors.white,
                  onSurface: AdminTheme.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
          });
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          ref.invalidate(dailyMenuStatusProvider(dateStr));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM dd, yyyy').format(_selectedDate),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainConfig(
    List<SessionModel> sessions,
    List<MenuItemModel> allItems,
    bool isDesktop,
    List<Map<String, dynamic>> releasedSessions,
  ) {
    final activeSessions = sessions.where((s) => s.isActive).toList();
    final releasedIds = releasedSessions.map((rs) => rs['sessionId']).toSet();
    final allReleased = activeSessions.isNotEmpty && 
                        activeSessions.every((s) => releasedIds.contains(s.id));

    if (allReleased) {
      return _buildAllReleasedView(isDesktop);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReleaseTypeSelector(),
        const SizedBox(height: 32),
        _buildSessionFilterChips(sessions, releasedSessions),
        const SizedBox(height: 32),
        // Draw in chronological order from sessions list
        ...sessions
            .where((s) => _selectedSessionIds.contains(s.id))
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: _buildActiveSessionConfig(_drafts[s.id]!, allItems),
              ),
            ),
        if (!isDesktop) ...[
          const SizedBox(height: 32),
          _buildMobileSummary(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isReleasing ? null : _confirmAndReleaseMenu,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('RELEASE MENU'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAllReleasedView(bool isDesktop) {
    return Center(
      child: AppFadeSlide(
        child: Container(
          width: isDesktop ? 600 : double.infinity,
          margin: EdgeInsets.only(top: isDesktop ? 100 : 40),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F4EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF1E8E3E),
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Today\'s Menu is Fully Released!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'All sessions and slots are now live and available for students to place orders.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AdminTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.adminDashboard),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: BorderSide(color: Colors.grey.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'DASHBOARD',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.go('/admin/live-menu'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'VIEW LIVE MENU',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseTypeSelector() {
    return _buildConfigSection(
      'RELEASE TYPE',
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypeOption(
              'Session Based',
              !_isFullDayMode,
              () => setState(() {
                _isFullDayMode = false;
                // When switching back to session mode, usually users expect to pick one
                // We'll keep the first one of the current selection or suggest next
                if (_selectedSessionIds.length > 1) {
                  final first = _selectedSessionIds.first;
                  _selectedSessionIds.clear();
                  _selectedSessionIds.add(first);
                }
              }),
            ),
            _buildTypeOption(
              'Full Day',
              _isFullDayMode,
              () => setState(() {
                _isFullDayMode = true;
                final releasedIds = (ref.read(releasedSessionsProvider(DateFormat('yyyy-MM-dd').format(_selectedDate))).value ?? [])
                    .map((s) => s['sessionId'] as String)
                    .toSet();

                _selectedSessionIds.clear();
                _selectedSessionIds.addAll(
                  _drafts.keys.where((sid) {
                    final draft = _drafts[sid]!;
                    return !_isSessionPast(draft.session) && !releasedIds.contains(sid);
                  }),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey,
                  width: isSelected ? 4 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.black : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSessionPast(SessionModel s) {
    final state = SessionStatusResolver.computeSessionState(
      selectedDate: _selectedDate,
      now: DateTime.now(),
      startTimeStr: s.startTime,
      endTimeStr: s.endTime,
      isReleased: false, // Just checking time component
    );
    return state.isPast;
  }

  Widget _buildSessionFilterChips(
    List<SessionModel> sessions,
    List<Map<String, dynamic>> releasedSessions,
  ) {
    final releasedIds = releasedSessions
        .map((s) => s['sessionId'] as String)
        .toSet();

    if (sessions.isEmpty) {
      return Text(
        'No sessions configured for this date.',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sessions.map((s) {
          final isReleased = releasedIds.contains(s.id);
          final state = SessionStatusResolver.computeSessionState(
            selectedDate: _selectedDate,
            now: DateTime.now(),
            startTimeStr: s.startTime,
            endTimeStr: s.endTime,
            isReleased: isReleased,
          );

          final isSelectable = state.isSelectableForRelease;
          final isSelected = _selectedSessionIds.contains(s.id);

          // Design specific colors based on session type and state
          Color activeColor = const Color(0xFF6366F1); // Default Blue
          Color lightBg = const Color(0xFFF3F4F6); // Default Grey Light
          Color borderCol = const Color(0xFFE5E7EB); // Default Border
          IconData sessionIcon = Icons.access_time_rounded;

          final nameLower = s.name.toLowerCase();
          
          if (nameLower.contains('breakfast')) {
            activeColor = const Color(0xFFF46AB2); // Pink Accent
            lightBg = const Color(0xFFFEE2E2); // Soft Pink
            borderCol = const Color(0xFFFECACA); 
            sessionIcon = Icons.coffee_rounded;
          } else if (nameLower.contains('lunch')) {
            activeColor = const Color(0xFF10B981); // Green Accent
            lightBg = const Color(0xFFD1FAE5); // Soft Green
            borderCol = const Color(0xFFA7F3D0);
            sessionIcon = Icons.restaurant_rounded;
          } else if (nameLower.contains('evening')) {
            activeColor = const Color(0xFF8B5CF6); // Purple Accent
            lightBg = const Color(0xFFEDE9FE); // Soft Purple
            borderCol = const Color(0xFFDDD6FE);
            sessionIcon = Icons.nights_stay_rounded;
          } else if (nameLower.contains('dinner')) {
            activeColor = const Color(0xFF6366F1); // Indigo Accent
            lightBg = const Color(0xFFE0E7FF); // Soft Indigo
            borderCol = const Color(0xFFC7D2FE);
            sessionIcon = Icons.dinner_dining_rounded;
          } else if (nameLower.contains('morning')) {
            activeColor = const Color(0xFFF59E0B); // Amber
            lightBg = const Color(0xFFFEF3C7);
            borderCol = const Color(0xFFFDE68A);
            sessionIcon = Icons.wb_sunny_rounded;
          } else if (nameLower.contains('tea') || nameLower.contains('snack')) {
            activeColor = const Color(0xFFEAB308); // Gold/Yellow
            lightBg = const Color(0xFFFFF9C4);
            borderCol = const Color(0xFFFFF176);
            sessionIcon = nameLower.contains('tea') ? Icons.emoji_food_beverage_rounded : Icons.cookie_rounded;
          } else if (_isFullDayMode) {
            activeColor = const Color(0xFF06B6D4); // Cyan Accent
            lightBg = const Color(0xFFE0F7FA); // Soft Cyan
            borderCol = const Color(0xFFB2EBF2);
            sessionIcon = Icons.calendar_today_rounded;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isSelectable
                    ? () {
                        setState(() {
                          if (isSelected) {
                            if (_selectedSessionIds.length > 1) {
                              _selectedSessionIds.remove(s.id);
                            }
                          } else {
                            _selectedSessionIds.add(s.id);
                          }
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !isSelectable
                        ? const Color(0xFFF3F4F6)
                        : isSelected
                            ? lightBg
                            : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !isSelectable
                          ? Colors.grey[300]!
                          : isSelected
                              ? borderCol
                              : AdminTheme.border,
                      width: isSelected ? 2 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeColor.withValues(alpha: 0.1)
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sessionIcon,
                          size: 16,
                          color: isSelected ? activeColor : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name.toLowerCase().contains('session') 
                                ? s.name.toUpperCase() 
                                : '${s.name.toUpperCase()} SESSION',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: isSelected ? activeColor.withValues(alpha: 0.9) : Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            isReleased ? 'RELEASED' : s.startTime,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: isSelected
                                  ? activeColor.withValues(alpha: 0.6)
                                  : AdminTheme.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveSessionConfig(
    _SessionDraft draft,
    List<MenuItemModel> allItems,
  ) {
    // Map session type to icon and color (Sync with chips)
    final nameLower = draft.session.name.toLowerCase();
    IconData sessionIcon = Icons.access_time_rounded;
    Color accentColor = const Color(0xFF6366F1); // Default Blue
    Color lightBg = const Color(0xFFFFFFFF); // Default White

    if (nameLower.contains('breakfast')) {
      sessionIcon = Icons.coffee_rounded;
      accentColor = const Color(0xFFF46AB2);
      lightBg = const Color(0xFFFEE2E2);
    } else if (nameLower.contains('lunch')) {
      sessionIcon = Icons.restaurant_rounded;
      accentColor = const Color(0xFF10B981);
      lightBg = const Color(0xFFD1FAE5);
    } else if (nameLower.contains('evening')) {
      sessionIcon = Icons.nights_stay_rounded;
      accentColor = const Color(0xFF8B5CF6);
      lightBg = const Color(0xFFEDE9FE);
    } else if (nameLower.contains('dinner')) {
      sessionIcon = Icons.dinner_dining_rounded;
      accentColor = const Color(0xFF6366F1);
      lightBg = const Color(0xFFE0E7FF);
    } else if (nameLower.contains('morning')) {
      sessionIcon = Icons.wb_sunny_rounded;
      accentColor = const Color(0xFFF59E0B);
      lightBg = const Color(0xFFFEF3C7);
    } else if (nameLower.contains('tea') || nameLower.contains('snack')) {
      sessionIcon = nameLower.contains('tea') ? Icons.emoji_food_beverage_rounded : Icons.cookie_rounded;
      accentColor = const Color(0xFFEAB308);
      lightBg = const Color(0xFFFFF9C4);
    } else if (_isFullDayMode) {
      sessionIcon = Icons.calendar_today_rounded;
      accentColor = const Color(0xFF06B6D4);
      lightBg = const Color(0xFFE0F7FA);
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: lightBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sessionIcon,
                color: accentColor,
                size: 28,
              ),
              const SizedBox(width: 16),
              Text(
                draft.session.name.toLowerCase().contains('session') 
                    ? draft.session.name.toUpperCase() 
                    : '${draft.session.name.toUpperCase()} SESSION',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E8E3E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configure timing and menu',
            style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildTimeInput(
                'START TIME',
                draft.session.startTime,
                () => _selectTime(draft.session.id, true),
              ),
              _buildTimeInput(
                'END TIME',
                draft.session.endTime,
                () => _selectTime(draft.session.id, false),
              ),
              _buildTimeInput(
                'SLOT INTERVAL',
                '${draft.session.defaultInterval} Mins',
                () => _editNumeric(
                  draft.session.id,
                  'Interval',
                  draft.session.defaultInterval,
                  true,
                ),
              ),
              _buildTimeInput(
                'SLOT CAPACITY',
                draft.session.defaultCapacity.toString(),
                () => _editNumeric(
                  draft.session.id,
                  'Capacity',
                  draft.session.defaultCapacity,
                  false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSlotPreviewHeader(draft),
          const SizedBox(height: 16),
          _buildHorizontalSlots(draft),
          const SizedBox(height: 48),
          _buildItemSelectionHeader(draft.session.id, allItems),
          const SizedBox(height: 24),
          _buildItemsGrid(draft),
        ],
      ),
    );
  }

  Widget _buildTimeInput(String label, String value, VoidCallback? onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AdminTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotPreviewHeader(_SessionDraft draft) {
    final visibleSlots = draft.slots.where((s) => s['isPast'] != true).toList();
    final allSelected =
        visibleSlots.isNotEmpty &&
        visibleSlots.every((s) => s['isSelected'] == true);
    final selectedCount = visibleSlots
        .where((s) => s['isSelected'] == true)
        .length;

    return Row(
      children: [
        const Icon(Icons.grid_view_rounded, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          'SLOT PREVIEW ($selectedCount/${visibleSlots.length} SELECTED)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: visibleSlots.isEmpty
              ? null
              : () {
                  setState(() {
                    final newVal = !allSelected;
                    for (var s in visibleSlots) {
                      s['isSelected'] = newVal;
                    }
                  });
                },
          child: Text(
            allSelected ? 'Deselect All' : 'Select All',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: visibleSlots.isEmpty ? Colors.grey : AdminTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalSlots(_SessionDraft draft) {
    final visibleSlots = draft.slots.where((s) => s['isPast'] != true).toList();
    if (visibleSlots.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTheme.border),
        ),
        child: Text(
          'No future slots available for this session.',
          style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    // Determine session-specific colors for slots
    Color activeColor = const Color(0xFF6366F1); // Default Blue
    if (draft.session.name.toLowerCase().contains('morning')) {
      activeColor = const Color(0xFFF59E0B); // Orange
    } else if (draft.session.name.toLowerCase().contains('lunch')) {
      activeColor = const Color(0xFFEAB308); // Yellow
    } else if (draft.session.name.toLowerCase().contains('evening')) {
      activeColor = const Color(0xFF8B5CF6); // Purple/Violet
    }

    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: visibleSlots.length,
        itemBuilder: (context, index) {
          final s = visibleSlots[index];
          final bool isSelected = s['isSelected'] == true;
          return GestureDetector(
            onTap: () {
              setState(() {
                s['isSelected'] = !isSelected;
              });
            },
            onLongPress: () => _editSlotCapacity(draft, index),
            child: Container(
              width: 155,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.black : const Color(0xFFE5E7EB),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SLOT ${index + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.black : Colors.grey[500],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${s['startTime']} – ${s['endTime']}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isSelected ? Colors.black : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withValues(alpha: 0.1)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CAP: ${s['capacity']}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? activeColor : Colors.grey[700],
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            color: isSelected ? activeColor : Colors.grey,
                            onPressed: () => _editSlotCapacity(draft, index),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isSelected ? activeColor : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? activeColor : Colors.grey[300]!,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: isSelected ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemSelectionHeader(
    String sessionId,
    List<MenuItemModel> allItems,
  ) {
    return Row(
      children: [
        const Icon(
          Icons.shopping_basket_outlined,
          color: Colors.black87,
          size: 22,
        ),
        const SizedBox(width: 12),
        Text(
          'Select Items',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        TextButton.icon(
          onPressed: () => _showAddItemPanel(sessionId, allItems),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('ADD FROM MENU'),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFF9FAFB),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const Spacer(),
        _buildSearchField(),
      ],
    );
  }

  Widget _buildItemsGrid(_SessionDraft draft) {
    final filteredItems = draft.items.where((it) {
      if (_mainSearchQuery.isEmpty) return true;
      return it.item.name.toLowerCase().contains(
        _mainSearchQuery.toLowerCase(),
      );
    }).toList();

    if (filteredItems.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_meals_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _mainSearchQuery.isEmpty
                  ? 'No items added to this session'
                  : 'No items match "$_mainSearchQuery"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.55, // Taller cards for better internal spacing
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final it = filteredItems[index];
        return AppFadeSlide(
          index: index,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF302F2C), // Premium Black (Sync with Dashboard)
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8), // Inner padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A), // Slightly lighter than pure black for separation
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (it.item.imageUrl != null &&
                            it.item.imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              it.item.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          const Center(
                            child: Icon(
                              Icons.fastfood_rounded,
                              color: Colors.white24,
                              size: 24,
                            ),
                          ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() => draft.items.remove(it)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            it.item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '₹${it.item.price.toInt()}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF10B981), // matching StudentTheme.statusGreen
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: StatefulBuilder(
                          builder: (context, setStockState) => AppQuantityStepper(
                            quantity: it.stock,
                            onIncrement: () {
                              setStockState(() => it.stock += 1);
                            },
                            onDecrement: () => setStockState(
                              () => it.stock = (it.stock - 1).clamp(0, 999),
                            ),
                            onTapValue: () => _editItemStock(it),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRightSummaryPanel() {
    int totalItems = 0;
    int totalCapacity = 0;
    int totalSlots = 0;
    for (var sid in _selectedSessionIds) {
      final d = _drafts[sid];
      if (d == null) continue;
      
      totalItems += d.items.length;
      final selectedSlots = d.slots
          .where((s) => s['isSelected'] == true && s['isPast'] != true)
          .toList();
      totalSlots += selectedSlots.length;
      totalCapacity += selectedSlots.fold(
        0,
        (sum, s) => sum + (s['capacity'] as int),
      );
    }

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AdminTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          size: 28,
                          color: AdminTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'RELEASE SUMMARY',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          color: Colors.black,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review and adjust menu for ${DateFormat('EEE, MMM d').format(_selectedDate)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AdminTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              children: _selectedSessionIds.map((sid) {
                final d = _drafts[sid]!;
                if (d.items.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AdminTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            d.session.name.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AdminTheme.textPrimary,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${d.items.length} items',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...d.items.map(
                        (it) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AdminTheme.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.item.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                    if (it.item.isPreReady) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'READY-MADE',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (it.stock > 1) it.stock--;
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                                    color: AdminTheme.textSecondary,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Container(
                                    width: 45,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${it.stock}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        it.stock++;
                                      });
                                    },
                                    icon: const Icon(Icons.add_circle_outline, size: 22),
                                    color: AdminTheme.primary,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        d.items.removeWhere((x) => x.item.id == it.item.id);
                                        _updateSlots(sid);
                                      });
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 20),
                                    color: Colors.red[400],
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSummaryLine(
                  'Total Capacity (Expected)',
                  totalCapacity.toString(),
                ),
                _buildSummaryLine('Slots Allocated', totalSlots.toString()),
                _buildSummaryLine('Total Items', totalItems.toString()),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (totalItems == 0 || _isReleasing)
                        ? null
                        : _confirmAndReleaseMenu,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isReleasing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.rocket_launch, size: 20),
                              const SizedBox(width: 16),
                              Text(
                                'RELEASE MENU',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSection(String label, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 250,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.border),
      ),
      child: TextField(
        onChanged: (val) {
          setState(() {
            _mainSearchQuery = val.trim();
          });
        },
        decoration: const InputDecoration(
          hintText: 'Search food items...',
          prefixIcon: Icon(Icons.search, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 8),
        ),
      ),
    );
  }

  Widget _buildMobileSummary() {
    int totalItems = 0;
    for (var d in _drafts.values) {
      totalItems += d.items.length;
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined, color: AdminTheme.primary),
          const SizedBox(width: 12),
          Text(
            '$totalItems items selected across sessions',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAddItemGrid(
    String sessionId,
    List<MenuItemModel> allItems,
    StateSetter setPanelState,
  ) {
    final draft = _drafts[sessionId]!;
    final filteredItems = allItems.where((item) {
      if (_itemSearchQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_itemSearchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_itemSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (context) {
                      final allSelected = filteredItems.isNotEmpty &&
                          filteredItems.every((item) =>
                              draft.items.any((it) => it.item.id == item.id));
                      return InkWell(
                        onTap: () {
                          setPanelState(() {
                            final newVal = !allSelected;
                            if (newVal) {
                              for (var item in filteredItems) {
                                if (!draft.items.any((it) => it.item.id == item.id)) {
                                  draft.items.add(_ItemDraft(item: item, stock: 10));
                                }
                              }
                            } else {
                              for (var item in filteredItems) {
                                draft.items.removeWhere((it) => it.item.id == item.id);
                              }
                            }
                            _updateSlots(sessionId);
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Checkbox(
                                value: allSelected,
                                activeColor: AdminTheme.primary,
                                shape: const CircleBorder(),
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  setPanelState(() {
                                    if (val == true) {
                                      for (var item in filteredItems) {
                                        if (!draft.items.any((it) => it.item.id == item.id)) {
                                          draft.items.add(_ItemDraft(item: item, stock: 10));
                                        }
                                      }
                                    } else {
                                      for (var item in filteredItems) {
                                        draft.items.removeWhere((it) => it.item.id == item.id);
                                      }
                                    }
                                    _updateSlots(sessionId);
                                  });
                                },
                              ),
                              Text(
                                'Select All',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Text(
                '${filteredItems.length} items available',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.58, // Taller for better proportion
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final existingIndex = draft.items.indexWhere(
              (it) => it.item.id == item.id,
            );
            final bool isSelected = existingIndex >= 0;
            final selectedDraft = isSelected
                ? draft.items[existingIndex]
                : null;

            return _GridItemCard(
              item: item,
              isSelected: isSelected,
              stock: selectedDraft?.stock ?? 0,
              onToggle: () {
                setPanelState(() {
                  if (isSelected) {
                    draft.items.removeAt(existingIndex);
                  } else {
                    draft.items.add(_ItemDraft(item: item, stock: 10));
                  }
                  _updateSlots(sessionId);
                });
              },
              onStockChanged: (newStock) {
                setPanelState(() {
                  if (isSelected) {
                    selectedDraft!.stock = newStock;
                    _updateSlots(sessionId);
                  }
                });
              },
            );
          },
        ),
      ],
    );
  }

  void _showAddItemPanel(String sessionId, List<MenuItemModel> allItems) {
    final draft = _drafts[sessionId]!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setPanelState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Items',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'To ${draft.session.name} (${draft.session.startTime} - ${draft.session.endTime})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.black54,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSearchFieldInPanel(setPanelState),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _buildCompactAddItemGrid(
                      sessionId,
                      allItems,
                      setPanelState,
                    ),
                  ),
                ),
                _buildPanelFooter(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchFieldInPanel(StateSetter setPanelState) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (val) => setPanelState(() {
              _itemSearchQuery = val;
            }),
            decoration: InputDecoration(
              hintText: 'Search menu...',
              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.black38),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.tune, color: Colors.black87),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildPanelFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle, size: 20),
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF191A1C),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        label: Text(
          'Done Adding',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}


class _GridItemCard extends StatefulWidget {
  final MenuItemModel item;
  final bool isSelected;
  final int stock;
  final VoidCallback onToggle;
  final Function(int) onStockChanged;

  const _GridItemCard({
    required this.item,
    required this.isSelected,
    required this.stock,
    required this.onToggle,
    required this.onStockChanged,
  });

  @override
  State<_GridItemCard> createState() => _GridItemCardState();
}

class _GridItemCardState extends State<_GridItemCard> {
  late int _localStock;

  @override
  void initState() {
    super.initState();
    _localStock = widget.stock;
  }

  @override
  void didUpdateWidget(_GridItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stock != widget.stock) {
      _localStock = widget.stock;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF302F2C), // Premium Black (Sync with Dashboard)
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: widget.isSelected 
                ? Colors.white.withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.1),
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.fastfood_rounded, color: Colors.white24, size: 24),
                            ),
                          )
                        : const Icon(Icons.fastfood_rounded, color: Colors.white24, size: 24),
                  ),
                  if (widget.isSelected)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: 1),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.black,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${widget.item.price.toStringAsFixed(0)}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: const Color(0xFF10B981),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    if (widget.isSelected)
                      Center(
                        child: AppQuantityStepper(
                          quantity: _localStock,
                          onIncrement: () {
                            setState(() => _localStock += 1);
                            widget.onStockChanged(_localStock);
                          },
                          onDecrement: () {
                            setState(() => _localStock = (_localStock - 1).clamp(0, 999));
                            widget.onStockChanged(_localStock);
                          },
                          color: Colors.white,
                        ),
                      )
                    else
                      Container(
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'ADD',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionDraft {
  SessionModel session;
  final List<_ItemDraft> items;
  List<Map<String, dynamic>> slots;
  String startTime;
  String endTime;
  int interval;
  int capacity;

  _SessionDraft({
    required this.session,
    required this.items,
    required this.slots,
    required this.startTime,
    required this.endTime,
    required this.interval,
    required this.capacity,
  });

  factory _SessionDraft.fromModel(
    SessionModel s,
    Map<String, dynamic> released,
  ) {
    final isReleased = released.isNotEmpty;
    final List<_ItemDraft> drafts = [];
    return _SessionDraft(
      session: s,
      items: drafts,
      slots: isReleased && released['slots'] != null
          ? List<Map<String, dynamic>>.from(released['slots'])
          : SlotHelper.generateSlots(
              startTimeStr: s.startTime,
              endTimeStr: s.endTime,
              intervalMinutes: s.defaultInterval,
              capacity: s.defaultCapacity,
              targetDate: DateTime.now(),
              customSlots: s.customSlots,
            ),
      startTime: isReleased
          ? (released['startTime'] ?? s.startTime)
          : s.startTime,
      endTime: isReleased ? (released['endTime'] ?? s.endTime) : s.endTime,
      interval: isReleased
          ? (released['interval'] ?? s.defaultInterval)
          : s.defaultInterval,
      capacity: isReleased
          ? (released['capacity'] ?? s.defaultCapacity)
          : s.defaultCapacity,
    );
  }
}

class _ItemDraft {
  final MenuItemModel item;
  int stock;

  _ItemDraft({required this.item, required this.stock});
}
