import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/time_helper.dart';
import '../../../app/themes/staff_theme.dart';
import '../providers/staff_providers.dart';
import '../../../core/providers.dart';
import '../widgets/staff_animated_queue.dart';
import '../widgets/staff_qr_scanner_sheet.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  final ScrollController _slotScrollController = ScrollController();
  String? _lastAutoSelectedSlotId;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _slotScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(currentDaySessionsWithStatusProvider);

    return Scaffold(
      backgroundColor: StaffTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(sessionsAsync),
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const Center(child: Text('No active sessions today.'));
                  }

                  // Auto-selection logic
                  final currentSessionId = ref.watch(staffSelectedSessionIdProvider);
                  if (currentSessionId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Map<String, dynamic>? bestSession;
                      for (var s in sessions) {
                        if (s['isLive'] == true) {
                          bestSession = s;
                          break;
                        }
                      }
                      if (bestSession == null) {
                        for (var s in sessions) {
                          if (s['timeState'] == 'upcoming') {
                            bestSession = s;
                            break;
                          }
                        }
                      }
                      bestSession ??= sessions.first;
                      ref.read(staffSelectedSessionIdProvider.notifier).state = bestSession['id'];
                    });
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeSlotsSection(),
                      _buildFilterChips(),
                      const Divider(height: 1, color: StaffTheme.border),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(currentDaySessionsWithStatusProvider);
                            ref.invalidate(staffOrdersStreamProvider);
                          },
                          color: StaffTheme.primaryOrange,
                          child: _buildTokensStream(),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error loading sessions: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<Map<String, dynamic>>> sessionsAsync) {
    String formattedTime = DateFormat('hh:mm a').format(_currentTime);
    final sessions = sessionsAsync.value ?? [];
    final isLive = sessions.any((s) => s['isLive'] == true);
    final allEnded = sessions.isNotEmpty && sessions.every((s) => s['isPast'] == true);

    final canteenAsync = ref.watch(canteenProvider);
    final canteenName = canteenAsync.value?.name ?? 'Tamarind House';

    final canteen = canteenAsync.value;
    bool isPastCloseTime = false;
    if (canteen != null) {
      final closeDt = TimeHelper.parseSessionTime(canteen.closeTime, _currentTime);
      if (closeDt != null && _currentTime.isAfter(closeDt)) {
        isPastCloseTime = true;
      }
    }

    final displayDayEnded = allEnded || isPastCloseTime;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canteenName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: StaffTheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formattedTime,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: StaffTheme.textSecondary),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const StaffQrScannerSheet(),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.tv_rounded, color: StaffTheme.textSecondary),
                    onPressed: () => context.push('/kitchen-tv'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: displayDayEnded 
                          ? StaffTheme.statusSkipped.withValues(alpha: 0.1) 
                          : (isLive ? Colors.green.shade100 : StaffTheme.statusPending.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLive && !displayDayEnded) ...[
                          _PulsingDot(color: Colors.green.shade500),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          displayDayEnded ? 'DAY ENDED' : (isLive ? 'ACTIVE' : 'IDLE'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: displayDayEnded 
                                ? StaffTheme.statusSkipped 
                                : (isLive ? Colors.green.shade700 : StaffTheme.statusPending),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrollToSlotIndex(int index) {
    if (!_slotScrollController.hasClients) return;
    const double chipWidth = 148.0;
    const double margin = 8.0; // horizontal: 4 * 2
    final double centerOffset = (MediaQuery.of(context).size.width / 2) - (chipWidth / 2);
    final double target = (index * (chipWidth + margin)) - centerOffset + 16.0; // +16 for initial padding
    
    _slotScrollController.animateTo(
      target.clamp(0.0, _slotScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildTimeSlotsSection() {
    final slotsAsync = ref.watch(staffAllDaySlotsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TIME SLOTS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Consumer(builder: (context, ref, child) {
                    final pace = ref.watch(staffSessionPaceProvider);
                    if (pace == null) return const SizedBox.shrink();
                    final isSlow = pace == 'Slow';
                    return Text(
                      'Serving $pace',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isSlow ? const Color(0xFFF97316) : const Color(0xFF166534),
                      ),
                    );
                  }),
                  Consumer(builder: (context, ref, child) {
                    final alert = ref.watch(nextSlotAlertProvider);
                    if (alert == null) return const SizedBox.shrink();
                    return Text(
                      alert,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD97706),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        slotsAsync.when(
          data: (slots) {
            if (slots.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('No slots for today.'),
              );
            }

            final selectedSlotId = ref.watch(staffSelectedSlotIdProvider);
            final now = DateTime.now();

            // 1. Find the "Best" slot (LIVE or first UPCOMING)
            String? bestSlotId;
            String? bestSessionId;
            int bestIndex = -1;

            // Priority 1: LIVE
            for (int i = 0; i < slots.length; i++) {
              final s = slots[i];
              final start = TimeHelper.parseSessionTime(s['startTime'], now);
              final end = TimeHelper.parseSessionTime(s['endTime'], now);
              if (start != null && end != null && TimeHelper.isTimeInWindow(now, start, end)) {
                bestSlotId = s['id'] as String;
                bestSessionId = s['sessionId'] as String?;
                bestIndex = i;
                break;
              }
            }
            // Priority 2: UPCOMING
            if (bestSlotId == null) {
              for (int i = 0; i < slots.length; i++) {
                final s = slots[i];
                final start = TimeHelper.parseSessionTime(s['startTime'], now);
                if (start != null && now.isBefore(start)) {
                  bestSlotId = s['id'] as String;
                  bestSessionId = s['sessionId'] as String?;
                  bestIndex = i;
                  break;
                }
              }
            }
            // Fallback: Last Slot if all ended
            if (bestSlotId == null) {
              bestSlotId = slots.last['id'] as String;
              bestSessionId = slots.last['sessionId'] as String?;
              bestIndex = slots.length - 1;
            }

            // AUTO-SELECTION & AUTO-SCROLL LOGIC
            // Run only when the actual "best" slot ID changes to avoid fighting manual scrolls
            if (bestSlotId != _lastAutoSelectedSlotId) {
              _lastAutoSelectedSlotId = bestSlotId;
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                // Update providers
                ref.read(staffSelectedSlotIdProvider.notifier).state = bestSlotId;
                if (bestSessionId != null) {
                  ref.read(staffSelectedSessionIdProvider.notifier).state = bestSessionId;
                }

                // SECONND frame scroll: after UI has reacted to provider updates
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && bestIndex != -1) {
                    _scrollToSlotIndex(bestIndex);
                  }
                });
              });
            }

            return SizedBox(
              height: 85,
              child: ListView.builder(
                controller: _slotScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  final id = slot['id'];
                  final sessionId = slot['sessionId'];
                  final isSelected = id == selectedSlotId;
                  
                  final startDt = TimeHelper.parseSessionTime(slot['startTime'], now);
                  final endDt = TimeHelper.parseSessionTime(slot['endTime'], now);
                  final isCurrent = startDt != null && endDt != null && TimeHelper.isTimeInWindow(now, startDt, endDt);

                  String label = slot['sessionName']?.toString().toUpperCase() ?? 'SCHEDULED';
                  if (endDt != null && now.isAfter(endDt)) {
                    label = 'ENDED';
                  } else if (isCurrent) {
                    label = 'LIVE';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _StaffSlotChip(
                      label: label,
                      timeText: '${slot['startTime']} - ${slot['endTime']}',
                      isSelected: isSelected,
                      isCurrent: isCurrent,
                      onTap: () {
                        // Manual select should probably NOT update _lastAutoSelectedSlotId
                        // but it should stop the "fighting" because we won't re-scroll
                        // unless the "live" slot itself transitions to a new ID.
                        ref.read(staffSelectedSlotIdProvider.notifier).state = id;
                        if (sessionId != null) {
                          ref.read(staffSelectedSessionIdProvider.notifier).state = sessionId;
                        }
                      },
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => const Text('Error loading slots'),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final selectedFilter = ref.watch(staffSelectedFilterProvider);
    final filters = [
      'All',
      'Pending',
      'Ready',
      'Partial',
      'Skipped',
      'Served',
      'Scheduled',
    ];

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter.toLowerCase();

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                ref.read(staffSelectedFilterProvider.notifier).state = filter.toLowerCase();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.grey.shade900 : StaffTheme.surface,
                  borderRadius: BorderRadius.circular(9999), 
                  border: Border.all(
                    color: isSelected ? Colors.transparent : StaffTheme.border,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x07000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTokensStream() {
    final ordersAsync = ref.watch(staffOrdersStreamProvider);
    return ordersAsync.when(
      data: (docs) {
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: StaffTheme.textTertiary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  'No tokens found',
                  style: GoogleFonts.splineSans(color: StaffTheme.textTertiary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }
        return StaffAnimatedQueue(
          key: ValueKey('queue_${ref.read(staffSelectedSessionIdProvider)}_${ref.read(staffSelectedSlotIdProvider)}'),
          docs: docs,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

class _StaffSlotChip extends StatelessWidget {
  final String label;
  final String timeText;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _StaffSlotChip({
    required this.label,
    required this.timeText,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? StaffTheme.primary : StaffTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? StaffTheme.primary : StaffTheme.border,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000), 
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : StaffTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color
              .withAlpha((102 + (_controller.value * 153)).toInt()),
          boxShadow: [
            BoxShadow(
              color: widget.color
                  .withAlpha((_controller.value * 128).toInt()),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
