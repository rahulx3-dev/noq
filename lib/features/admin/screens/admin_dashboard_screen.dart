import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../core/models/canteen_model.dart';
import '../../../core/models/admin_models.dart';
import '../../../app/themes/admin_theme.dart';
import '../widgets/slot_analysis_chart.dart';
import '../widgets/bestselling_list.dart';
import '../widgets/order_traffic_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../app/app_routes.dart';

import '../../../core/utils/time_helper.dart';
import '../../../core/utils/session_status_resolver.dart';
import '../../../core/widgets/app_motion_widgets.dart';
import '../services/admin_notification_service.dart';
import '../providers/admin_alert_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  // Banner auto-scroll
  final PageController _adminBannerController = PageController();
  Timer? _adminBannerTimer;
  int _currentAdminBanner = 0;

  // Background logic now handled by AdminAlertNotifier to prevent spam.

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
        // Logic now handled globally by AdminAlertNotifier to prevent spam.
        // Dashboard only handles immediate UI state & banners.
      }
    });
    // Banner auto-scroll timer
    _adminBannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_adminBannerController.hasClients) return;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final released = ref.read(releasedSessionsProvider(dateStr)).value ?? [];
      final stats = ref.read(statsByPeriodProvider((start: dateStr, end: dateStr)));
      final lowItems = ref.read(criticalStockItemsProvider);
      final bannerCount = _getBannerCount(released, stats, lowItems);
      if (bannerCount <= 1) return;
      final next = (_currentAdminBanner + 1) % bannerCount;
      setState(() => _currentAdminBanner = next);
      _adminBannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
    // Logic now handled globally by AdminAlertNotifier
  }

  @override
  void dispose() {
    _timer.cancel();
    _adminBannerTimer?.cancel();
    _adminBannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canteenAsync = ref.watch(canteenProvider);
    final isToday =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final stats = ref.watch(statsByPeriodProvider((start: dateStr, end: dateStr)));
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final releasedAsync = ref.watch(releasedSessionsProvider(dateStr));
    final theme = Theme.of(context);

    // NEW: Trends and Low Stock for Banners
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
    final compareArgs = (current: (start: dateStr, end: dateStr), previous: (start: yesterdayStr, end: yesterdayStr));
    final trends = ref.watch(comparativeStatsProvider(compareArgs));
    final lowItems = ref.watch(criticalStockItemsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isDesktop ? 40 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, canteenAsync, isDesktop),
                const SizedBox(height: 24),
                _buildAdminBannerSection(stats, releasedAsync.value ?? [], trends, lowItems),
                const SizedBox(height: 16),
                _buildActionBanner(context),
                const SizedBox(height: 48),
                _buildSectionTitle(Icons.bolt, 'Quick Actions', Colors.orange),
                const SizedBox(height: 16),
                _buildQuickActionsGrid(context, isDesktop),
                const SizedBox(height: 48),
                _buildSectionTitle(
                  Icons.bar_chart,
                  isToday
                      ? 'Live Stats (Today)'
                      : 'Stats (${DateFormat('MMM d').format(_selectedDate)})',
                  Colors.redAccent,
                ),
                Consumer(builder: (context, ref, _) {
                  final yesterday = DateTime.now().subtract(const Duration(days: 1));
                  final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
                  final compareArgs = (current: (start: dateStr, end: dateStr), previous: (start: yesterdayStr, end: yesterdayStr));
                  final trends = ref.watch(comparativeStatsProvider(compareArgs));
                  final sessions = ref.watch(sessionsStreamProvider);
                  
                  return _buildStatsGrid(isDesktop, stats, trends, sessions);
                }),
                const SizedBox(height: 48),
                _buildSectionTitle(
                  Icons.schedule,
                  isToday
                      ? "Today's Sessions"
                      : 'Sessions (${DateFormat('MMM d').format(_selectedDate)})',
                  Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                _buildSessionsList(isDesktop, sessionsAsync, releasedAsync),
                
                // --- NEW ANALYSIS WIDGETS ---
                const SizedBox(height: 48),
                _buildSectionTitle(Icons.show_chart, 'Slot-wise Analysis & Bestselling', const Color(0xFF3B82F6)),
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final yesterdayStr = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
                    final yesterdayStats = ref.watch(statsByPeriodProvider((start: yesterdayStr, end: yesterdayStr)));
                    
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: SlotAnalysisChart(
                            todayStats: stats,
                            yesterdayStats: yesterdayStats,
                          ),
                        ),
                        if (isDesktop) const SizedBox(width: 24),
                        if (isDesktop)
                          Expanded(
                            flex: 1,
                            child: BestsellingList(
                              itemSales: stats['itemSales'] ?? [],
                            ),
                          ),
                      ],
                    );
                  }
                ),
                if (!isDesktop) ...[
                  const SizedBox(height: 24),
                  BestsellingList(itemSales: stats['itemSales'] ?? []),
                ],

                const SizedBox(height: 48),
                _buildSectionTitle(Icons.radar, 'Order Traffic', const Color(0xFF8B5CF6)),
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final weeklyData = ref.watch(weeklyTrafficProvider);
                    return weeklyData.when(
                      data: (traffic) {
                        return Row(
                          children: [
                            Expanded(
                              flex: isDesktop ? 1 : 1,
                              child: OrderTrafficChart(trafficData: traffic),
                            ),
                            if (isDesktop) const Expanded(flex: 1, child: SizedBox.shrink()),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Text('Error loading traffic: $e'),
                    );
                  }
                ),
                const SizedBox(height: 60), // bottom padding
              ],
            ),
          );

        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<CanteenModel?> canteenAsync,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) ...[
          Center(
            child: Text(
              'noq',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.black,
                fontSize: 64, // Bigger brand for mobile
                fontWeight: FontWeight.w800,
                letterSpacing: -4.0,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  canteenAsync.when(
                    data: (canteen) => Row(
                      children: [
                        if (canteen?.logoUrl != null)
                          Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage(canteen!.logoUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: AdminTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.restaurant_menu,
                                size: 16,
                                color: Colors.white,
                              ),
                          ),
                        Text(
                          (canteen?.name ?? 'TAMARIND HOUSE').toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16, // Adjusted for space
                            fontWeight: FontWeight.w500,
                            color: AdminTheme.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        _buildCanteenStatus(canteen),
                      ],
                    ),
                    loading: () => const SizedBox(height: 24),
                    error: (e, s) {
                    final errorStr = e.toString().toLowerCase();
                    if (errorStr.contains('network') || errorStr.contains('unavailable')) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) context.go('/admin/no-network');
                      });
                    }
                    return const SizedBox.shrink();
                  },
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final now = DateTime.now();
                      final hour = now.hour;
                      String greetingText = 'Good morning';
                      if (hour >= 12 && hour < 17) {
                        greetingText = 'Good afternoon';
                      } else if (hour >= 17 || hour < 5) {
                        greetingText = 'Good night';
                      }

                      final profileAsync = ref.watch(userProfileProvider);
                      final adminName = profileAsync.maybeWhen(
                        data: (p) => p?.displayName ?? 'Admin',
                        orElse: () => 'Admin',
                      );

                      return Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            '$greetingText, $adminName',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isDesktop ? 32 : 20,
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AdminTheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'ADMIN',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            if (isDesktop)
              Row(
                children: [
                  Text(
                    DateFormat('hh:mm a').format(_currentTime),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  _buildDateDropdown(),
                  const SizedBox(width: 20),
                  _buildMenuReleasedPill(),
                  const SizedBox(width: 20),
                  _buildNotificationIcon(context),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.tv),
                    color: AdminTheme.primary,
                    tooltip: 'Launch Kitchen TV',
                    onPressed: () => context.push('/kitchen-tv'),
                  ),
                ],
              )
            else
              _buildNotificationIcon(context),
          ],
        ),
      ],
    );
  }

  Widget _buildDateDropdown() {
    final isToday =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final label = isToday
        ? 'Today'
        : DateFormat('dd MMM yyyy').format(_selectedDate);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (picked != null) {
          setState(
            () =>
                _selectedDate = DateTime(picked.year, picked.month, picked.day),
          );
          ref.invalidate(
            dailyMenuStatusProvider(DateFormat('yyyy-MM-dd').format(picked)),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }


  /// Uses SessionStatusResolver to determine the live release status.
  /// Returns: { anyLive, liveSessionName, nextUnreleased, allDone }
  Map<String, dynamic> _computeTimeAwareStatus(
    List<Map<String, dynamic>> releasedSessions,
    List<SessionModel> allSessions,
  ) {
    final now = _currentTime;
    bool anyLive = false;
    String? currentLiveSessionName;

    // Check if any released session is currently live using the resolver
    for (var rs in releasedSessions) {
      final state = SessionStatusResolver.computeSessionState(
        selectedDate: _selectedDate,
        now: now,
        startTimeStr: rs['startTime'] ?? '',
        endTimeStr: rs['endTime'] ?? '',
        isReleased: true,
      );
      if (state.isLive) {
        anyLive = true;
        currentLiveSessionName = rs['name'] ?? 'Session';
        break;
      }
    }

    // Find next unreleased session — STRICT: skip past sessions
    final releasedIds = releasedSessions.map((r) => r['sessionId']).toSet();
    SessionModel? nextUnreleased;
    for (var s in allSessions.where((s) => s.isActive)) {
      if (releasedIds.contains(s.id)) continue;
      final state = SessionStatusResolver.computeSessionState(
        selectedDate: _selectedDate,
        now: now,
        startTimeStr: s.startTime,
        endTimeStr: s.endTime,
        isReleased: false,
      );
      // Strictly upcoming. Not past, not live.
      if (state.isUpcoming) {
        nextUnreleased = s;
        break;
      }
    }

    // Check if all sessions are done for the day — STRICT
    bool allDone = SessionStatusResolver.areAllSessionsEnded(
      selectedDate: _selectedDate,
      now: now,
      sessions: allSessions.where((s) => s.isActive).toList(),
    );

    return {
      'anyLive': anyLive,
      'liveSessionName': currentLiveSessionName,
      'nextUnreleased': nextUnreleased,
      'allDone': allDone,
    };
  }

  /// Periodic check for 60/30/10 minute reminder popups

  /// Checks if any released session ended with leftovers

  Widget _buildMenuReleasedPill() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final releasedAsync = ref.watch(releasedSessionsProvider(dateStr));
    final sessionsAsync = ref.watch(sessionsStreamProvider);

    final now = _currentTime;
    final todayStart = DateTime(now.year, now.month, now.day);
    final selectedDayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final isPastDate = selectedDayStart.isBefore(todayStart);
    final isToday =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(now);

    return releasedAsync.when(
      data: (releasedSessions) {
        if (releasedSessions.isEmpty) {
          // Not released at all
          String label = isPastDate
              ? 'PAST DATE'
              : (isToday ? 'NOT RELEASED' : 'UPCOMING');
          return _buildPillWidget(
            label,
            isPastDate ? Colors.grey : const Color(0xFFB06000),
            isPastDate ? Colors.grey.shade100 : const Color(0xFFFEEFC3),
          );
        }

        if (!isToday) {
          // Future or past date with releases
          return _buildPillWidget(
            isPastDate ? 'COMPLETED' : 'RELEASED',
            isPastDate ? Colors.grey : const Color(0xFF1E8E3E),
            isPastDate ? Colors.grey.shade100 : const Color(0xFFE6F4EA),
          );
        }

        // Today — check if any released session is still active
        final allSessions = sessionsAsync.value ?? [];
        final status = _computeTimeAwareStatus(releasedSessions, allSessions);

        if (status['anyLive'] == true) {
          return _buildPillWidget(
            'MENU LIVE',
            const Color(0xFF1E8E3E),
            const Color(0xFFE6F4EA),
            isLive: true,
          );
        } else if (status['allDone'] == true) {
          return _buildPillWidget(
            'DAY COMPLETED',
            Colors.grey.shade700,
            Colors.grey.shade200,
          );
        } else {
          return _buildPillWidget(
            'RELEASED',
            const Color(0xFF1E8E3E),
            const Color(0xFFE6F4EA),
          );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildPillWidget(
    String label,
    Color textColor,
    Color bgColor, {
    bool isLive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppStatusGlow(
            isActive: isLive,
            color: textColor,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
    );
  }

  Widget _buildActionBanner(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final releasedAsync = ref.watch(releasedSessionsProvider(dateStr));
    final sessionsAsync = ref.watch(sessionsStreamProvider);

    final now = _currentTime;
    final todayStart = DateTime(now.year, now.month, now.day);
    final selectedDayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final isPastDate = selectedDayStart.isBefore(todayStart);
    final isToday =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(now);

    return releasedAsync.when(
      data: (releasedSessions) {
        // CASE: No releases exist for this date
        if (releasedSessions.isEmpty) {
          if (isPastDate) {
            return _buildPastDateBanner();
          }

          // Check if all sessions for today are already concluded
          if (isToday) {
            final allSessions = sessionsAsync.value ?? [];
            final allPast = SessionStatusResolver.areAllSessionsEnded(
              selectedDate: _selectedDate,
              now: now,
              sessions: allSessions.where((s) => s.isActive).toList(),
            );

            if (allPast && allSessions.isNotEmpty) {
              return _buildDayEndedBanner();
            }
          }

          return _buildReleaseActionBanner();
        }

        // CASE: Not today — show static status
        if (!isToday) {
          return _buildLiveBanner(
            isPastDate ? 'MENU WAS RELEASED' : 'MENU IS RELEASED FOR THIS DATE',
          );
        }

        // CASE: Today — time-aware
        final allSessions = sessionsAsync.value ?? [];
        final status = _computeTimeAwareStatus(releasedSessions, allSessions);

        if (status['anyLive'] == true) {
          final name = status['liveSessionName'] ?? 'Session';
          return _buildLiveBanner('$name — MENU IS LIVE');
        }

        if (status['allDone'] == true) {
          return _buildDayEndedBanner();
        }

        // Next unreleased session exists
        final nextSession = status['nextUnreleased'] as SessionModel?;
        if (nextSession != null) {
          return InkWell(
            onTap: () => context.go(AppRoutes.adminRelease, extra: _selectedDate),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminTheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AdminTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
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
                          'Release ${nextSession.name} Menu',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${nextSession.startTime} – ${nextSession.endTime} · Not released yet',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 32,
                  ),
                ],
              ),
            ),
          );
        }

        // Fallback: all released, but none currently live
        return _buildLiveBanner('MENU RELEASED');
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, s) {
        debugPrint('Dashboard Banner Error: $e');
        return _buildReleaseActionBanner();
      },
    );
  }

  Widget _buildPastDateBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Past Date — View Only',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.grey[700],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No menu was released on this date.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.history, color: Colors.grey[400], size: 32),
        ],
      ),
    );
  }

  Widget _buildReleaseActionBanner() {
    return InkWell(
      onTap: () => context.go(AppRoutes.adminRelease, extra: _selectedDate),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.black, // Match Admin Sidebar/Nav Bar
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.rocket_launch, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Release Daily Menu',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set items and slots for today\'s sessions',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF166534),
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color accentColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, bool isDesktop) {
    final actions = [
      _ActionData(
        Icons.restaurant_menu,
        'Manage Menu',
        'Add items, update prices',
        '/admin/manage-menu',
      ),
      _ActionData(
        Icons.bolt,
        'Live Menu',
        'Update stock & capacity live',
        AppRoutes.adminLiveMenu,
      ),
      _ActionData(
        Icons.receipt_long,
        'View Orders',
        'Track active orders live',
        AppRoutes.adminOrders,
      ),
      _ActionData(
        Icons.settings,
        'Settings',
        'Configure system preferences',
        AppRoutes.adminProfile,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 100,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) => _buildQuickActionCard(context, actions[index]),
        );
      },
    );
  }

  Widget _buildQuickActionCard(BuildContext context, _ActionData data) {
    return InkWell(
      onTap: () => context.go(data.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF302F2C), // Slot Wise Analysis background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AdminTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    bool isDesktop,
    Map<String, dynamic> stats,
    Map<String, String> trends,
    AsyncValue<List<SessionModel>> sessionsAsync,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
        
        final currentSession = sessionsAsync.when(
          data: (sessions) {
            final now = DateTime.now();
            final live = sessions.where((s) {
              final status = SessionStatusResolver.computeSessionState(
                selectedDate: _selectedDate,
                now: now,
                startTimeStr: s.startTime,
                endTimeStr: s.endTime,
                isReleased: true, // Assuming released if it's live
              );
              return status.isLive;
            }).toList();
            return live.isNotEmpty ? "${live.first.name} in progress" : "No session in progress";
          },
          loading: () => "Loading session...",
          error: (_, __) => "Error loading session",
        );

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.6 : 1.9,
          children: [
            _buildStatCard(
              'Total Revenue',
              '₹${stats['totalRevenue']}',
              trends['revenueTrend'] ?? '0%',
              Icons.currency_rupee_rounded,
              const Color(0xFFE8F5C8), // GreenLight
              _getSpotsFromMap(stats['hourlyRevenue'] ?? {}),
            ),
            _buildStatCard(
              'Total Orders',
              stats['totalOrders'].toString(),
              trends['ordersTrend'] ?? '0%',
              Icons.receipt_long_rounded,
              const Color(0xFFC4B8F0), // PurpleAccent
              _getSpotsFromMap(stats['hourlyOrders'] ?? {}),
            ),
            _buildStatCard(
              'Units Sold',
              stats['totalItemsSold'].toString(),
              trends['unitsSoldTrend'] ?? '0%',
              Icons.restaurant_menu_rounded,
              const Color(0xFFF4A8C4), // PinkAccent
              _getSpotsFromMap(stats['hourlyUnits'] ?? {}),
            ),
            _buildStatCard(
              'Active Tokens',
              stats['activeTokens']?.toString() ?? '0',
              currentSession, // Dynamic session name
              Icons.token_rounded,
              const Color(0xFFE8F5C8), // GreenLight (same as revenue)
              _getSpotsFromMap(stats['hourlyOrders'] ?? {}),
            ),
          ],
        );
      },
    );
  }

  List<FlSpot> _getSpotsFromMap(Map<int, dynamic> data) {
    if (data.isEmpty) {
      return [const FlSpot(0, 0), const FlSpot(23, 0)];
    }
    
    List<FlSpot> spots = [];
    
    // Fill in gaps to make the line continuous and start/end correctly
    for (int i = 0; i <= 24; i++) {
        double val = (data[i] ?? 0).toDouble();
        spots.add(FlSpot(i.toDouble(), val));
    }
    
    return spots;
  }

  Widget _buildStatCard(
    String label,
    String value,
    String trend,
    IconData icon,
    Color accentColor,
    List<FlSpot> graphData,
  ) {
    final isPositive = trend.startsWith('+');
    final isNeutral = trend == '0%' || trend == 'Live' || trend.isEmpty;
    
    // Convert 'Live' trend badge to neutral grey
    final trendColor = isNeutral
        ? Colors.grey.shade600
        : (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    final trendBgColor = isNeutral
        ? Colors.grey.shade100
        : (isPositive ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF302F2C), // Slot Wise Analysis background (Same as Quick Actions)
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background soft line using LineChart
          if (graphData.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    minX: 0,
                    maxX: 24,
                    minY: 0,
                    maxY: (graphData.isEmpty ? 1.0 : graphData.map((s) => s.y).reduce((a, b) => a > b ? a : b)) * 1.5,
                    lineBarsData: [
                      LineChartBarData(
                        spots: graphData,
                        isCurved: true,
                        color: accentColor.withValues(alpha: 0.8),
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.3),
                              accentColor.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              top: 16, // Reduced top
              left: 20,
              right: 20,
              bottom: label == 'Active Tokens' ? 52 : 16, // Reduced bottom
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8), // Reduced spacing from 12
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    if (trend.isNotEmpty && label != 'Active Tokens')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: trendBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: trendColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${isPositive ? '▲' : '▼'} ${trend.replaceAll('+', '').replaceAll('-', '')}",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15, // Significantly increased
                                fontWeight: FontWeight.w900,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (label == 'Active Tokens')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Live',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12), // Reduced spacing from 20
                AppAnimatedValue(
                  value: value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 38, // Slightly bigger
                    fontWeight: FontWeight.w900, // Slightly bolder
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                if (label == 'Active Tokens')
                    Text(
                      'Ready for pickup',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                else
                    Text(
                      'vs yesterday',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              ],
            ),
          ),
          // Active Tokens floating status box
          if (label == 'Active Tokens')
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trend, // This is currentSession now
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE8F5C8), // Matching GreenLight
                        ),
                      ),
                    ),
                    Text(
                      value, // Token count
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE8F5C8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(
    bool isDesktop,
    AsyncValue<List<SessionModel>> sessionsAsync,
    AsyncValue<List<Map<String, dynamic>>> releasedAsync,
  ) {
    return releasedAsync.when(
      data: (releasedSessions) {
        final releasedIds = releasedSessions.map((r) => r['sessionId']).toSet();
        return sessionsAsync.when(
          data: (sessions) {
            final activeOnes = sessions.where((s) => s.isActive).toList();
            if (activeOnes.isEmpty) {
              return const Text('No active sessions configured.');
            }

            // Sort sessions by time to find the first upcoming one
            final sortedSessions = List<SessionModel>.from(activeOnes)
              ..sort((a, b) {
                final aStart = TimeHelper.parseSessionTime(a.startTime, _selectedDate) ?? DateTime(9999);
                final bStart = TimeHelper.parseSessionTime(b.startTime, _selectedDate) ?? DateTime(9999);
                return aStart.compareTo(bStart);
              });

            final now = DateTime.now();
            String? firstUpcomingId;
            for (var s in sortedSessions) {
              final start = TimeHelper.parseSessionTime(s.startTime, _selectedDate);
              if (start != null && start.isAfter(now)) {
                firstUpcomingId = s.id;
                break;
              }
            }

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: activeOnes
                  .map(
                    (s) => SizedBox(
                      width: isDesktop
                          ? (MediaQuery.of(context).size.width - 200) / 4
                          : double.infinity,
                      child: SessionCard(
                        session: s,
                        selectedDate: _selectedDate,
                        isReleased: releasedIds.contains(s.id),
                        isFirstUpcoming: s.id == firstUpcomingId,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Text('Error: $e'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }

  Widget _buildDayEndedBanner() {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.grey[600], size: 24),
          const SizedBox(width: 16),
          Text(
            isToday
                ? 'ALL SESSIONS COMPLETED FOR TODAY'
                : 'ALL SESSIONS COMPLETED',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final unreadCount = ref.watch(unreadAdminNotificationsCountProvider);
        // Also watch alert provider to ensure timers run
        ref.watch(adminAlertProvider);

        return InkWell(
          onTap: () => context.push(AppRoutes.adminNotifications),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  color: AdminTheme.textPrimary,
                  size: 22,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AdminTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCanteenStatus(CanteenModel? canteen) {
    if (canteen == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final openDt = TimeHelper.parseSessionTime(canteen.openTime, now);
    final closeDt = TimeHelper.parseSessionTime(canteen.closeTime, now);

    bool isActive = false;
    if (openDt != null && closeDt != null) {
      isActive = TimeHelper.isTimeInWindow(now, openDt, closeDt) && canteen.isOpenToday;
    }

    final color = isActive ? AdminTheme.success : AdminTheme.error;
    final label = isActive ? 'ACTIVE' : 'CLOSED';

    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppStatusGlow(
            isActive: isActive,
            color: color,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Dynamic Banner helpers ─────────────────────────────────────────────

  /// Returns how many banners would be shown given current data.
  int _getBannerCount(
    List<Map<String, dynamic>> released,
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> lowItems,
  ) {
    int count = 0;
    final now = _currentTime;
    for (var rs in released) {
      final endDt = TimeHelper.parseSessionTime(rs['endTime'] ?? '', _selectedDate);
      if (endDt == null) continue;
      final minsLeft = endDt.difference(now).inMinutes;
      if (minsLeft > 0 && minsLeft <= 20) {
        final pending = (stats['activeTokens'] ?? 0) as int;
        if (pending > 0) count++;
      }
    }

    if (lowItems.isNotEmpty) count++;

    final pending = (stats['activeTokens'] ?? 0) as int;
    if (pending >= 5) count++;
    final revenue = (stats['totalRevenue'] ?? 0) as num;
    final milestones = [1000, 2500, 5000, 10000, 25000];
    for (var m in milestones) {
      if (revenue >= m && revenue < m * 1.1) {
        count++;
        break;
      }
    }
    return count;
  }

  List<Map<String, dynamic>> _buildAdminBanners(
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> released,
    Map<String, String> trends,
    List<Map<String, dynamic>> lowItems,
  ) {
    final banners = <Map<String, dynamic>>[];
    final now = _currentTime;

    // 1. Session ending soon banner (< 20 mins, has pending orders)
    for (var rs in released) {
      final endDt = TimeHelper.parseSessionTime(rs['endTime'] ?? '', _selectedDate);
      if (endDt == null) continue;
      final minsLeft = endDt.difference(now).inMinutes;
      if (minsLeft > 0 && minsLeft <= 20) {
        final pending = (stats['activeTokens'] ?? 0) as int;
        if (pending > 0) {
          banners.add({
            'color': const Color(0xFF7F1D1D),
            'tagColor': const Color(0xFFFCA5A5),
            'tag': '⏰ SESSION ENDING SOON',
            'title': '${rs['name'] ?? 'Session'} ends in ${minsLeft}m',
            'sub': '$pending tokens still pending pickup',
            'action': 'Release Now',
            'route': AppRoutes.adminRelease,
            'icon': Icons.timer_outlined,
          });
        }
      }
    }

    // 2. Low stock alert
    if (lowItems.isNotEmpty) {
      banners.add({
        'color': const Color(0xFF78350F),
        'tag': '⚠ LOW STOCK ALERT',
        'title': '${lowItems.length} items critically low',
        'sub': lowItems.take(3).map((i) => i['name']).join(' · '),
        'action': 'Update Stock',
        'route': AppRoutes.adminLiveMenu,
        'icon': Icons.warning_amber_outlined,
        'tagColor': const Color(0xFFFCD34D),
      });
    }

    // 3. Revenue milestone banner
    final revenue = (stats['totalRevenue'] ?? 0) as num;
    final milestones = [1000, 2500, 5000, 10000, 25000];
    for (var m in milestones) {
      if (revenue >= m && revenue < m * 1.1) {
        banners.add({
          'color': const Color(0xFF14532D),
          'tagColor': const Color(0xFF6EE7B7),
          'tag': '📈 REVENUE MILESTONE',
          'title': '₹${m.toStringAsFixed(0)} crossed today!',
          'sub': trends['revenueTrend'] != null
              ? '${trends['revenueTrend']} vs yesterday'
              : 'Great performance today',
          'action': 'View Stats',
          'route': AppRoutes.adminReports,
          'icon': Icons.trending_up_rounded,
        });
        break;
      }
    }

    // 4. Pending orders banner (≥5 pending)
    final pending = (stats['activeTokens'] ?? 0) as int;
    if (pending >= 5) {
      banners.add({
        'color': const Color(0xFF1E3A5F),
        'tagColor': const Color(0xFF93C5FD),
        'tag': '🔔 PENDING ORDERS',
        'title': '$pending orders waiting',
        'sub': 'Students are waiting for pickup',
        'action': 'Go to Orders',
        'route': AppRoutes.adminOrders,
        'icon': Icons.receipt_long_outlined,
      });
    }

    return banners;
  }

  Widget _buildAdminBannerSection(
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> released,
    Map<String, String> trends,
    List<Map<String, dynamic>> lowItems,
  ) {
    final banners = _buildAdminBanners(stats, released, trends, lowItems);
    if (banners.isEmpty) return const SizedBox.shrink();

    // Clamp current index if banners list shrank
    if (_currentAdminBanner >= banners.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentAdminBanner = 0);
      });
    }

    return Column(
      children: [
        SizedBox(
          height: 92,
          child: PageView(
            controller: _adminBannerController,
            onPageChanged: (i) => setState(() => _currentAdminBanner = i),
            children: banners.map((b) => _adminBannerCard(b)).toList(),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentAdminBanner == i
                      ? AdminTheme.primary
                      : Colors.grey.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _adminBannerCard(Map<String, dynamic> b) {
    return GestureDetector(
      onTap: () => context.go(b['route'] as String),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: b['color'] as Color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(b['icon'] as IconData, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    b['tag'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: b['tagColor'] as Color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    b['title'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    b['sub'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                b['action'] as String,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionCard extends ConsumerWidget {
  final SessionModel session;
  final DateTime selectedDate;
  final bool isReleased;
  final bool isFirstUpcoming;

  const SessionCard({
    super.key,
    required this.session,
    required this.selectedDate,
    required this.isReleased,
    this.isFirstUpcoming = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = SessionStatusResolver.computeSessionState(
      selectedDate: selectedDate,
      now: DateTime.now(),
      startTimeStr: session.startTime,
      endTimeStr: session.endTime,
      isReleased: isReleased,
    );

    Color statusColor;
    String statusText;
    Color bgColor;
    Color textColor;

    final isToday = DateFormat('yyyy-MM-dd').format(selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isFuture = selectedDate.isAfter(DateTime.now()) && !isToday;
    final isPast = selectedDate.isBefore(DateTime.now()) && !isToday;

    if (isPast) {
      statusColor = Colors.grey;
      statusText = 'ENDED';
      bgColor = Colors.grey.shade50;
      textColor = AdminTheme.textSecondary;
    } else if (isFuture) {
      statusColor = const Color(0xFF3B82F6); // Blue for scheduled
      statusText = 'SCHEDULED';
      bgColor = Colors.white;
      textColor = AdminTheme.textPrimary;
    } else {
      // Today logic
      if (state.isLive) {
        statusColor = const Color(0xFF10B981);
        statusText = 'LIVE';
        bgColor = const Color(0xFFD1FAE5); // Light green for live
        textColor = const Color(0xFF064E3B);
      } else if (state.isUpcoming) {
        if (isFirstUpcoming) {
          statusColor = const Color(0xFFFFFFFF);
          statusText = 'UP NEXT';
          bgColor = Colors.black; // Premium Black theme for up-next
          textColor = Colors.white;
        } else {
          statusColor = const Color(0xFF3B82F6);
          statusText = 'SCHEDULED';
          bgColor = const Color(0xFFEFF6FF); // Light blue for scheduled
          textColor = const Color(0xFF1E40AF);
        }
      } else {
        statusColor = Colors.grey;
        statusText = 'ENDED';
        bgColor = Colors.grey.shade100; // Grey faded for ended
        textColor = Colors.grey.shade600;
      }
    }

    final statsAsync = ref.watch(sessionStatsProvider(session.id));

    IconData sessionIcon = Icons.access_time_rounded;
    String nameUpper = session.name.toUpperCase();
    if (nameUpper.contains('MORNING')) {
      sessionIcon = Icons.wb_sunny_rounded;
    } else if (nameUpper.contains('BREAKFAST')) {
      sessionIcon = Icons.coffee_rounded;
    } else if (nameUpper.contains('LUNCH')) {
      sessionIcon = Icons.restaurant_rounded;
    } else if (nameUpper.contains('TEA')) {
      sessionIcon = Icons.emoji_food_beverage_rounded;
    } else if (nameUpper.contains('SNACK') || nameUpper.contains('BREAK')) {
      sessionIcon = Icons.cookie_rounded;
    } else if (nameUpper.contains('EVENING')) {
      sessionIcon = Icons.nights_stay_rounded;
    } else if (nameUpper.contains('DINNER')) {
      sessionIcon = Icons.dinner_dining_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: state.isLive || (state.isUpcoming && isFirstUpcoming) ? Colors.transparent : AdminTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: state.isLive
                      ? Colors.white.withValues(alpha: 0.1)
                      : (isFirstUpcoming ? Colors.white.withValues(alpha: 0.5) : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(color: state.isLive || isFirstUpcoming ? Colors.transparent : AdminTheme.border),
                ),
                child: Icon(
                  sessionIcon,
                  color: state.isLive ? Colors.white : AdminTheme.textPrimary,
                  size: 24,
                ),
              ),
              AppStatusGlow(
                isActive: isToday, // Pulsing for all today's sessions
                color: isFirstUpcoming ? const Color(0xFF10B981) : statusColor,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: state.isLive ? const Color(0xFF1E293B) : (isFirstUpcoming ? const Color(0xFF10B981) : statusColor.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.isLive) ...[
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        statusText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: state.isLive ? Colors.white : (isFirstUpcoming ? Colors.white : statusColor),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            session.name,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${session.startTime} - ${session.endTime}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          statsAsync.when(
            data: (stats) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSessionMetric('ADDED', stats['added'].toString(), textColor),
                _buildSessionMetric('STOCK', stats['stock'].toString(), textColor),
                _buildSessionMetric('SOLD', stats['sold'].toString(), textColor),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSessionMetric('ADDED', '--', textColor),
                _buildSessionMetric('STOCK', '--', textColor),
                _buildSessionMetric('SOLD', '--', textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionMetric(String label, String value, Color baseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: baseColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        AppAnimatedValue(
          value: value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: baseColor,
          ),
        ),
      ],
    );
  }
}


class _ActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  _ActionData(this.icon, this.title, this.subtitle, this.route);
}
