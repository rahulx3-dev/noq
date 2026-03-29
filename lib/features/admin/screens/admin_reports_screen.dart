import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../app/themes/admin_theme.dart';
import '../widgets/admin_breadcrumbs.dart';
import '../providers/admin_analytics_providers.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _bg          = Colors.white;
const _cardBg      = Color(0xFF302F2C);
const _cardBorder  = Color(0x12FFFFFF); // white 7%
const _rev         = Color(0xFFE8F5C8);
const _ord         = Color(0xFFC4B8F0);
const _units       = Color(0xFFF4A8C4);
const _tok         = Color(0xFF93C5FD);
const _pos         = Color(0xFF10B981);
const _neg         = Color(0xFFEF4444);
const _warn        = Color(0xFFF59E0B);
const _secLabel    = Color(0x59FFFFFF); // white 35%
const _divider     = Color(0x12FFFFFF); // white 7%

// ─── Root screen ─────────────────────────────────────────────────────────────
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

enum DateFilter { today, thisWeek, thisMonth, custom }

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  DateFilter _dateFilter = DateFilter.today;
  DateTime _customStart = DateTime.now();
  DateTime _customEnd = DateTime.now();
  String get _selectedDate => _currentPeriod.end;
  late TabController _graphTab;

  DatePeriod get _currentPeriod {
    final now = DateTime.now();
    switch (_dateFilter) {
      case DateFilter.today:
        final str = DateFormat('yyyy-MM-dd').format(now);
        return (start: str, end: str);
      case DateFilter.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (start: DateFormat('yyyy-MM-dd').format(start), end: DateFormat('yyyy-MM-dd').format(now));
      case DateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (start: DateFormat('yyyy-MM-dd').format(start), end: DateFormat('yyyy-MM-dd').format(now));
      case DateFilter.custom:
        return (start: DateFormat('yyyy-MM-dd').format(_customStart), end: DateFormat('yyyy-MM-dd').format(_customEnd));
    }
  }

  DatePeriod get _previousPeriod {
    final now = DateTime.now();
    switch (_dateFilter) {
      case DateFilter.today:
        final p = now.subtract(const Duration(days: 1));
        final str = DateFormat('yyyy-MM-dd').format(p);
        return (start: str, end: str);
      case DateFilter.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1 + 7));
        final end = now.subtract(Duration(days: now.weekday));
        return (start: DateFormat('yyyy-MM-dd').format(start), end: DateFormat('yyyy-MM-dd').format(end));
      case DateFilter.thisMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return (start: DateFormat('yyyy-MM-dd').format(start), end: DateFormat('yyyy-MM-dd').format(end));
      case DateFilter.custom:
        final diff = _customEnd.difference(_customStart).inDays;
        final pEnd = _customStart.subtract(const Duration(days: 1));
        final pStart = pEnd.subtract(Duration(days: diff));
        return (start: DateFormat('yyyy-MM-dd').format(pStart), end: DateFormat('yyyy-MM-dd').format(pEnd));
    }
  }

  @override
  void initState() {
    super.initState();
    _graphTab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _graphTab.dispose();
    super.dispose();
  }

  // ── keep these two unchanged ──────────────────────────────────────────────
  Widget _buildDateFilterToggles(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _filterPill('Today', DateFilter.today),
          _filterPill('This Week', DateFilter.thisWeek),
          _filterPill('This Month', DateFilter.thisMonth),
          _customFilterPill(),
        ],
      ),
    );
  }

  Widget _filterPill(String label, DateFilter filter) {
    final active = _dateFilter == filter;
    return InkWell(
      onTap: () => setState(() => _dateFilter = filter),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _bg : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? _cardBg : Colors.white,
        )),
      ),
    );
  }

  Widget _customFilterPill() {
    final active = _dateFilter == DateFilter.custom;
    final label = active
        ? DateFormat('MMM d').format(_customStart)
        : 'Custom';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: active ? _customStart : DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _customStart = picked;
            _customEnd = picked;
            _dateFilter = DateFilter.custom;
          });
        }
      },
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _bg : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 14, color: active ? _cardBg : Colors.white),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? _cardBg : Colors.white,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 100),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
        const SizedBox(height: 24),
        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(message, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AdminTheme.textSecondary)),
      ]),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop   = MediaQuery.of(context).size.width > 900;
    final selectedDt  = DateFormat('yyyy-MM-dd').parse(_selectedDate);
    final stats       = ref.watch(statsByPeriodProvider(_currentPeriod));
    final trends      = ref.watch(comparativeStatsProvider((current: _currentPeriod, previous: _previousPeriod)));
    final isFuture    = selectedDt.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final hasData     = (stats['totalOrders'] ?? 0) > 0;

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 40 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isDesktop) ...[
            AdminBreadcrumbs(items: [AdminBreadcrumbItem(label: 'Home', route: '/admin'), AdminBreadcrumbItem(label: 'Reports & Analytics')]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.bar_chart, color: Colors.white, size: 24)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Analytics and reports', style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
              ])),
              if (isDesktop) _buildDateFilterToggles(context),
            ]),
          ] else ...[
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                Text('Analytics', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
              ]),
              _buildDateFilterToggles(context),
            ]),
          ],

          const SizedBox(height: 32),

          if (isFuture)
            _buildEmptyState('No data for future dates', 'Select a past date to view reports')
          else if (!hasData)
            _buildEmptyState('No activity on this date', 'Select another date to view reports')
          else ...[
            ref.watch(sevenDayStatsProvider).when(
              data: (seven) => _buildKpiRow(isDesktop, stats, trends, seven),
              loading: () => _buildKpiRow(isDesktop, stats, trends, []),
              error: (e, st) {
                final err = e.toString().toLowerCase();
                if (err.contains('network') || err.contains('unavailable')) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) context.go('/admin/no-network');
                  });
                }
                return _buildKpiRow(isDesktop, stats, trends, []);
              },
            ),
            const SizedBox(height: 12),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildHourlyChart(stats, isDesktop),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildTopItems(stats)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildCategoryDonut(stats)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildStudentBehaviour(stats)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildWasteEfficiency()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildSessionBreakdown(),
                        const SizedBox(height: 12),
                        _buildSlotHeatmap(),
                        const SizedBox(height: 12),
                        _buildPaymentInsights(),
                        const SizedBox(height: 12),
                        _buildTomorrowAlerts(isDesktop),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _buildHourlyAndSessions(isDesktop, stats),
              const SizedBox(height: 12),
              _buildItemsCategorySlots(isDesktop, stats),
              const SizedBox(height: 12),
              _buildStudentWastePaymentTomorrow(isDesktop, stats),
            ],
            const SizedBox(height: 16),
            _buildTokenSection(isDesktop),
            const SizedBox(height: 16),
            _buildLineGraphSection(isDesktop, stats),
            const SizedBox(height: 100),
          ],
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — KPI ROW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildKpiRow(bool isDesktop, Map<String, dynamic> stats, Map<String, String> trends, List<Map<String, dynamic>> seven) {
    List<double> hist(String key) {
       if (seven.isEmpty) {
         return List.filled(7, 10.0);
       }
       return seven.reversed.map((s) => (s[key] as num?)?.toDouble() ?? 0.0).toList();
    }
    List<double> avgHist() {
       if (seven.isEmpty) {
         return List.filled(7, 10.0);
       }
       return seven.reversed.map((s) {
         final r = (s['revenue'] as num?)?.toDouble() ?? 0.0;
         final o = (s['orders'] as num?)?.toDouble() ?? 0.0;
         return o > 0 ? r / o : 0.0;
       }).toList();
    }
    final items = [
      _KpiData('REVENUE',    '₹${stats['totalRevenue'] ?? 0}',        _rev,   trends['revenueTrend']   ?? '0%', hist('revenue')),
      _KpiData('ORDERS',     '${stats['totalOrders'] ?? 0}',          _ord,   trends['ordersTrend']    ?? '0%', hist('orders')),
      _KpiData('UNITS SOLD', '${stats['totalItemsSold'] ?? 0}',       _units, trends['unitsSoldTrend'] ?? '0%', hist('orders')),
      _KpiData('AVG ORDER VALUE',
        stats['totalOrders'] != null && ((stats['totalOrders'] as int?) ?? 0) > 0
          ? '₹${(((stats['totalRevenue'] as num?) ?? 0) / ((stats['totalOrders'] as int?) ?? 1)).toStringAsFixed(0)}'
          : '—',
        _tok, '', avgHist()),
    ];
    final children = items.map((k) => _KpiCard(data: k)).toList();
    if (isDesktop) {
      return SizedBox(
        height: 175,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children.map((c) => Expanded(child: Padding(padding: EdgeInsets.only(right: c == children.last ? 0 : 12), child: c))).toList()),
      );
    }
    return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15, children: children);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — HOURLY CHART + SESSION BREAKDOWN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHourlyAndSessions(bool isDesktop, Map<String, dynamic> stats) {
    final hourly   = _buildHourlyChart(stats, isDesktop);
    final sessions = _buildSessionBreakdown();
    if (isDesktop) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: hourly),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: sessions),
      ]);
    }
    return Column(children: [hourly, const SizedBox(height: 12), sessions]);
  }

  Widget _buildHourlyChart(Map<String, dynamic> stats, bool isDesktop) {
    final hourlyRaw = stats['hourlyOrders'] as Map<dynamic, dynamic>? ?? {};
    final Map<int, int> hourly = {};
    hourlyRaw.forEach((k, v) => hourly[int.tryParse(k.toString()) ?? 0] = ((v as num?) ?? 0).toInt());

    final List<BarChartGroupData> bars = [];
    double maxV = 1;
    for (int h = 8; h <= 20; h++) {
       final v = hourly[h] ?? 0;
       if (v > maxV) maxV = v.toDouble();
    }
    for (int h = 8; h <= 20; h++) {
      final v = hourly[h] ?? 0;
      Color c = h >= 16 ? _units : h >= 12 ? _ord : _rev;
      bars.add(BarChartGroupData(x: h, barRods: [
        BarChartRodData(
          toY: v.toDouble(),
          color: c.withValues(alpha: 0.85),
          width: isDesktop ? 22 : 16,
          borderRadius: BorderRadius.vertical(top: Radius.circular(isDesktop ? 4 : 3)),
          backDrawRodData: BackgroundBarChartRodData(show: false),
        ),
      ]));
    }

    return _Card(
      title: 'Order traffic — hourly',
      subtitle: 'Orders placed per hour today',
      child: Column(children: [
        SizedBox(
          height: 120,
          child: BarChart(BarChartData(
            groupsSpace: 2,
            alignment: BarChartAlignment.center,
            maxY: maxV < 5 ? 5 : (maxV * 1.2),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _cardBg,
                tooltipBorder: const BorderSide(color: _cardBorder),
                getTooltipItem: (g, a, rod, b) {
                  final h = g.x.toInt(); final isPM = h >= 12;
                  final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
                  return BarTooltipItem('$dh${isPM ? 'pm' : 'am'}\n', GoogleFonts.plusJakartaSans(color: _secLabel, fontSize: 10),
                    children: [TextSpan(text: '${rod.toY.toInt()} orders', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]);
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final h = v.toInt();
                  if (h % 2 != 0) return const SizedBox.shrink();
                  final isPM = h >= 12; final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
                  return Text('$dh${isPM ? 'pm' : 'am'}', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel));
                },
              )),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: bars,
          )),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _LegendDot(color: _rev, label: 'Breakfast'),
          const SizedBox(width: 16),
          _LegendDot(color: _ord, label: 'Lunch'),
          const SizedBox(width: 16),
          _LegendDot(color: _units, label: 'Evening'),
        ]),
      ]),
    );
  }

  TimeOfDay _parseTime(String ts) {
    if (ts.isEmpty) return const TimeOfDay(hour: 0, minute: 0);
    try {
      final p = ts.split(' ');
      final tm = p[0].split(':');
      int h = int.parse(tm[0]);
      int m = tm.length > 1 ? int.parse(tm[1]) : 0;
      if (p.length > 1 && p[1].toUpperCase() == 'PM' && h != 12) h += 12;
      if (p.length > 1 && p[1].toUpperCase() == 'AM' && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    } catch (_) { return const TimeOfDay(hour: 0, minute: 0); }
  }

  Widget _buildSessionBreakdown() {
    final dateStr = _selectedDate;
    final stats   = ref.watch(statsByPeriodProvider((start: dateStr, end: dateStr)));
    final released = ref.watch(releasedSessionsProvider(dateStr));
    final sessionStats = (stats['sessionStats'] as Map<String, dynamic>?) ?? {};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session performance', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('Revenue · orders · sell-through', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel)),
          const SizedBox(height: 14),
          released.when(
            loading: () => const _Shimmer(height: 180),
            error: (e, _) => _ErrorText(e.toString()),
            data: (releasedList) {
              if (releasedList.isEmpty) return const _EmptyText('No sessions released');
              return Column(
                children: releasedList.map((rs) {
                  final sId      = rs['sessionId'] as String;
                  final sName    = (rs['sessionNameSnapshot'] ?? rs['name'] ?? 'Session').toString();
                  final start    = (rs['startTime'] ?? '').toString();
                  final end_     = (rs['endTime']   ?? '').toString();
                  final through  = ref.watch(sessionSellThroughProvider(sId));

                  final sKey     = sName.toUpperCase();
                  final sStat    = (sessionStats[sKey] as Map<String, dynamic>?) ?? {};
                  final rev      = ((sStat['revenue'] as num?) ?? 0).toDouble();
                  final orders   = ((sStat['orders'] as int?) ?? 0);

                  // Map sessions to primary KPI colors: Revenue, Orders, Units Sold
                  final palette = [_rev, _ord, _units, _tok];
                  final Color accent = palette[releasedList.indexOf(rs) % palette.length];

                  final nowT  = TimeOfDay.now();
                  final sStart = _parseTime(start);
                  final sEnd   = _parseTime(end_);
                  String sLabel = 'UPCOMING';
                  Color sLabelColor = _secLabel;
                  if (nowT.hour > sEnd.hour || (nowT.hour == sEnd.hour && nowT.minute >= sEnd.minute)) {
                    sLabel = 'COMPLETED'; sLabelColor = _secLabel;
                  } else if (nowT.hour > sStart.hour || (nowT.hour == sStart.hour && nowT.minute >= sStart.minute)) {
                    sLabel = 'LIVE ●'; sLabelColor = _pos;
                  }

                  final sellPct = through.valueOrNull ?? 0.0;
                  final sellColor = sellPct >= 80 ? _pos : sellPct >= 50 ? _warn : _neg;

                  return Container(
                    margin: EdgeInsets.only(bottom: rs == releasedList.last ? 0 : 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(sName, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: sLabelColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(sLabel, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: sLabelColor, letterSpacing: 0.5)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text('$start – $end_', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _MicroStat('Revenue', '₹${rev.toStringAsFixed(0)}', _rev),
                        _MicroStat('Orders', '$orders', _ord),
                        _MicroStat('Sell-through', '${sellPct.toStringAsFixed(0)}%', sellColor),
                      ]),
                    ]),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3 — TOP ITEMS + CATEGORY + SLOT HEATMAP
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildItemsCategorySlots(bool isDesktop, Map<String, dynamic> stats) {
    final col1 = _buildTopItems(stats);
    final col2 = _buildCategoryDonut(stats);
    final col3 = _buildSlotHeatmap();
    if (isDesktop) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: col1), const SizedBox(width: 12),
        Expanded(child: col2), const SizedBox(width: 12),
        Expanded(child: col3),
      ]);
    }
    return Column(children: [col1, const SizedBox(height: 12), col2, const SizedBox(height: 12), col3]);
  }

  Widget _buildTopItems(Map<String, dynamic> stats) {
    final items  = stats['itemSales'] as List<dynamic>? ?? [];
    final colors = [_rev, _ord, _tok, _units, _warn];

    return _Card(
      title: 'Top Items',
      subtitle: 'Ordered by quantity',
      child: Column(
        children: items.take(5).toList().asMap().entries.map((e) {
          final rank  = e.key + 1;
          final item  = e.value as Map<String, dynamic>;
          final qty   = (item['quantity'] ?? 0) as int;
          final name  = (item['name']     ?? 'Item').toString();
          final maxQ  = items.isNotEmpty ? (items.first['quantity'] as int? ?? 1) : 1;
          final pct   = maxQ > 0 ? (qty / maxQ).clamp(0.0, 1.0) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                SizedBox(width: 20, child: Text('$rank', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: _secLabel))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Stack(
                        children: [
                          Container(height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(2))),
                          FractionallySizedBox(widthFactor: pct, child: Container(height: 4, decoration: BoxDecoration(color: colors[e.key % colors.length], borderRadius: BorderRadius.circular(2)))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$qty', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('units', style: GoogleFonts.plusJakartaSans(fontSize: 8, color: _secLabel)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryDonut(Map<String, dynamic> stats) {
    final catRev    = stats['categorySales'] as Map<String, double>? ?? {};
    final catAsync  = ref.watch(categoriesStreamProvider);
    final catNames  = catAsync.whenOrNull(data: (cats) => {for (var c in cats) c.id: c.name}) ?? {};
    final total     = catRev.values.fold(0.0, (a, b) => a + b);
    final entries   = catRev.entries.where((e) => e.value > 0).toList();
    final colors    = [_rev, _ord, _tok, _units, _warn];

    // vs yesterday
    final selectedDt = DateFormat('yyyy-MM-dd').parse(_selectedDate);
    final prevDay    = DateFormat('yyyy-MM-dd').format(selectedDt.subtract(const Duration(days: 1)));
    final prevStats  = ref.watch(statsByPeriodProvider((start: prevDay, end: prevDay)));
    final prevCatRev = prevStats['categorySales'] as Map<String, double>? ?? {};

    return _Card(
      title: 'Revenue by category',
      subtitle: 'Tap segment to highlight',
      child: entries.isEmpty
          ? const _EmptyText('No category data')
          : Column(children: [
              _CategoryDonut(entries: entries, catNames: catNames, total: total, colors: colors),
              if (prevCatRev.isNotEmpty) ...[
                Divider(color: _divider, height: 20),
                _SecLabel('VS YESTERDAY'),
                const SizedBox(height: 8),
                ...entries.asMap().entries.map((e) {
                  final catId  = e.value.key;
                  final curV   = e.value.value;
                  final prevV  = prevCatRev[catId] ?? 0.0;
                  final chg    = prevV > 0 ? ((curV - prevV) / prevV * 100) : (curV > 0 ? 100.0 : 0.0);
                  final color  = colors[e.key % colors.length];
                  final name   = catNames[catId] ?? catId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      Expanded(child: Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel))),
                      Text('${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(0)}%',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800,
                          color: chg >= 0 ? _pos : _neg)),
                    ]),
                  );
                }),
              ],
            ]),
    );
  }

  Widget _buildSlotHeatmap() {
    final heatmap = ref.watch(slotHeatmapProvider(_selectedDate));
    return _Card(
      title: 'Slot pickup heatmap',
      subtitle: 'Orders per time slot',
      child: heatmap.when(
        loading: () => _Shimmer(height: 140),
        error: (e, _) => _ErrorText(e.toString()),
        data: (slots) {
          if (slots.isEmpty) return const _EmptyText('No slot data');
          final maxO = slots.map((s) => (s['ordersInSlot'] as int?) ?? 0).fold(0, (a, b) => a > b ? a : b);
          return Column(children: [
            Wrap(spacing: 8, runSpacing: 8, children: slots.map((s) {
              final count = (s['ordersInSlot'] as int?) ?? 0;
              final pct   = maxO > 0 ? (count / maxO).clamp(0.0, 1.0) : 0.0;
              
              // Heatmap intensity: Red (high), Orange/Amber (med), Blue (low)
              final color = pct >= 0.8 ? _neg 
                          : pct >= 0.4 ? _warn 
                          : _tok;
              final alpha = pct.clamp(0.15, 1.0);

              return Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                   color: color.withValues(alpha: alpha * 0.4),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: color.withValues(alpha: alpha * 0.6)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(s['startTime'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text('$count', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                ]),
              );
            }).toList()),
            Divider(color: _divider, height: 20),
            _SecLabel('SLOT EFFICIENCY'),
            _WaitRow('Slot utilisation', () {
              final total  = slots.length;
              if (total == 0) return '—';
              final avg = slots.map((s) => ((s['utilisation'] as num?) ?? 0.0).toDouble()).fold(0.0, (a, b) => a + b) / total;
              return '${avg.toStringAsFixed(0)}%';
            }()),
            _WaitRow('No-show tokens', () {
              final stats = ref.watch(tokenConsumptionProvider((start: _selectedDate, end: _selectedDate)));
              return stats.whenOrNull(data: (d) => '${d['noShow']} tokens') ?? '—';
            }()),
          ]);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4 — STUDENT + WASTE + PAYMENT + TOMORROW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStudentWastePaymentTomorrow(bool isDesktop, Map<String, dynamic> stats) {
    final cols = [
      _buildStudentBehaviour(stats),
      _buildWasteEfficiency(),
      _buildPaymentInsights(),
      _buildTomorrowAlerts(isDesktop),
    ];
    if (isDesktop) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: cols.map((c) => Expanded(child: Padding(padding: EdgeInsets.only(right: c == cols.last ? 0 : 12), child: c))).toList());
    }
    return Column(children: cols.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
  }

  Widget _buildStudentBehaviour(Map<String, dynamic> stats) {
    final uniqueAsync = ref.watch(uniqueStudentsProvider((start: _selectedDate, end: _selectedDate)));
    final cartAsync   = ref.watch(cartBehaviourProvider(_selectedDate));
    final totalOrders = (stats['totalOrders'] as int?) ?? 0;
    final totalRev    = ((stats['totalRevenue'] as num?) ?? 0).toDouble();
    return _Card(
      title: 'Student behaviour',
      subtitle: 'Ordering patterns today',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        uniqueAsync.when(
          loading: () => _Shimmer(height: 120),
          error: (e, _) => const SizedBox.shrink(),
          data: (unique) => Column(children: [
            Row(children: [
              Expanded(child: _BigStat('$unique', 'Unique students', _rev)),
              const SizedBox(width: 8),
              Expanded(child: cartAsync.when(
                loading: () => _BigStat('—', 'Avg items/order', _ord),
                error: (_,__) => _BigStat('—', 'Avg items/order', _ord),
                data: (c) => _BigStat((c['avgItemsPerOrder'] as double?)?.toStringAsFixed(1) ?? '—', 'Avg items/order', _ord),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _BigStat('${unique > 0 && totalOrders > unique ? ((totalOrders - unique) / totalOrders * 100).toStringAsFixed(0) : '0'}%', 'Repeat orderers', _tok)),
              const SizedBox(width: 8),
              Expanded(child: cartAsync.when(
                loading: () => _BigStat('—', 'Avg spend/student', _units),
                error: (_,__) => _BigStat('—', 'Avg spend/student', _units),
                data: (c) => _BigStat('₹${unique > 0 ? (totalRev / unique).toStringAsFixed(0) : '0'}', 'Avg spend/student', _units),
              )),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        _SecLabel('CART BEHAVIOUR'),
        const SizedBox(height: 12),
        cartAsync.when(
          loading: () => _Shimmer(height: 80),
          error: (e, _) => const SizedBox.shrink(),
          data: (c) {
            final added = (c['addedToCart'] as int?) ?? 0;
            final wl = (c['wishlistToCartRate'] as double?) ?? 0.0;
            final ab = (c['abandonmentRate'] as double?) ?? 0.0;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SessionMetricRow('Added to wishlist', '$added items', Colors.white),
              const SizedBox(height: 12),
              _SessionMetricRow('Wishlist → cart rate', '${wl.toStringAsFixed(0)}%', _pos),
              const SizedBox(height: 12),
              _SessionMetricRow('Cart abandonment', '${ab.toStringAsFixed(0)}%', _neg),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _buildWasteEfficiency() {
    final wasteAsync = ref.watch(wasteAnalysisProvider(_selectedDate));
    return _Card(
      title: 'Waste & efficiency',
      subtitle: 'Leftover stock after sessions',
      child: wasteAsync.when(
        loading: () => _Shimmer(height: 200),
        error: (e, _) => _ErrorText(e.toString()),
        data: (waste) {
          final total         = ((waste['totalWasteValue'] as num?) ?? 0).toDouble();
          final sessionWaste  = (waste['sessionWaste'] as Map<String, dynamic>?) ?? {};
          final items         = (waste['wasteItems'] as List?) ?? [];
          final colors        = [_neg, _warn, _ord, _tok, _units];
          final entries       = sessionWaste.entries.where((e) => ((e.value as num?) ?? 0) > 0).toList();
          final wTotal        = entries.fold(0.0, (s, e) => s + ((e.value as num?) ?? 0).toDouble());

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Donut chart
            if (entries.isNotEmpty) SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 55,
                    sections: entries.asMap().entries.map((e) {
                      final v = ((e.value.value as num?) ?? 0).toDouble();
                      return PieChartSectionData(
                        value: v, color: colors[e.key % colors.length],
                        radius: 35, showTitle: false,
                      );
                    }).toList(),
                  )),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('₹${total.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: total > 0 ? _neg : _pos)),
                    Text('est. waste', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SecLabel('BY SESSION'),
            ...sessionWaste.entries.toList().asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
                Expanded(child: Text(e.value.key, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _secLabel))),
                Text('₹${((e.value.value as num?) ?? 0).toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: colors[e.key % colors.length])),
              ]),
            )),
            if (items.isNotEmpty) ...[
              Divider(color: _divider, height: 16),
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _neg.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _neg.withValues(alpha: 0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Carry-over suggestion', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: _neg)),
                  const SizedBox(height: 4),
                  ...items.take(2).map((i) => Text('${i['name']} (${i['stock']}u) → ${i['sessionName']}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel))),
                ]),
              ),
            ],
          ]);
        },
      ),
    );
  }

  Widget _buildPaymentInsights() {
    final payAsync = ref.watch(paymentBreakdownProvider((start: _selectedDate, end: _selectedDate)));
    final stats    = ref.watch(statsByPeriodProvider((start: _selectedDate, end: _selectedDate)));
    return _Card(
      title: 'Payment insights',
      subtitle: 'UPI transaction breakdown',
      child: payAsync.when(
        loading: () => _Shimmer(height: 160),
        error: (e, _) => _ErrorText(e.toString()),
        data: (pay) {
          final total   = ((pay['total']   as int?) ?? 0).toDouble();
          final gpay    = ((pay['gpay']     as int?) ?? 0).toDouble();
          final phonepe = ((pay['phonepe']  as int?) ?? 0).toDouble();
          final others  = ((pay['others']   as int?) ?? 0).toDouble();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('₹${stats['totalRevenue'] ?? 0}', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1, color: _pos)),
            Text('total collected', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel)),
            const SizedBox(height: 12),
            _SecLabel('BY METHOD'),
            _PayRow('Google Pay', gpay, total, _rev),
            _PayRow('PhonePe',    phonepe, total, _ord),
            _PayRow('Others',     others,  total, _units),
            Divider(color: _divider, height: 16),
            _SecLabel('STATUS'),
            _WaitRow('Success rate', '${pay['successRate']}%'),
            _WaitRow('Failed orders', '${pay['failed']} orders'),
          ]);
        },
      ),
    );
  }

  Widget _buildTomorrowAlerts(bool isDesktop) {
    final nextDay     = DateFormat('yyyy-MM-dd').format(DateFormat('yyyy-MM-dd').parse(_selectedDate).add(const Duration(days: 1)));
    final tomorrowSt  = ref.watch(statsByPeriodProvider((start: nextDay, end: nextDay)));
    final wasteAsync  = ref.watch(wasteAnalysisProvider(_selectedDate));
    final tokAsync    = ref.watch(tokenConsumptionProvider((start: _selectedDate, end: _selectedDate)));

    return Column(children: [
      _Card(
        title: "Tomorrow's outlook",
        subtitle: 'Based on pre-orders + patterns',
        child: Column(children: [
          _WaitRow('Pre-orders', '${tomorrowSt['totalOrders'] ?? 0}'),
          _WaitRow('Forecast revenue', '₹${tomorrowSt['totalRevenue'] ?? 0}'),
          _WaitRow('Sessions planned', '${tomorrowSt['sessionsPlanned'] ?? 0}'),
          _WaitRow('Slots configured', '${tomorrowSt['slotsConfigured'] ?? 0}'),
        ]),
      ),
      const SizedBox(height: 12),
      _Card(
        title: 'LIVE ALERTS',
        subtitle: '',
        child: Column(children: [
          wasteAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (waste) {
              final items = ((waste['wasteItems'] as List?) ?? []).where((i) => ((i['stock'] as int?) ?? 0) < 5 && ((i['stock'] as int?) ?? 0) > 0).toList();
              return Column(children: items.take(2).map((i) => _AlertRow('Low stock — ${i['name']}', '${i['stock']} units left', _neg)).toList());
            },
          ),
          tokAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (tok) {
              final pending = (tok['pending'] as int?) ?? 0;
              if (pending > 5) return _AlertRow('$pending tokens pending', 'Students waiting for pickup', _warn);
              return const SizedBox.shrink();
            },
          ),
          _AlertRow('Reports updated', 'Analytics refreshed live', _pos),
        ]),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5 — TOKEN CONSUMPTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTokenSection(bool isDesktop) {
    final tokAsync = ref.watch(tokenConsumptionProvider(_currentPeriod));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SecLabel('TOKEN CONSUMPTION ANALYTICS'),
      const SizedBox(height: 10),
      tokAsync.when(
        loading: () => _Shimmer(height: 200),
        error: (e, _) => _ErrorText(e.toString()),
        data: (tok) {
          final generated   = (tok['generated']       as int?)     ?? 0;
          final served_     = (tok['served']           as int?)     ?? 0;
          final pending_    = (tok['pending']          as int?)     ?? 0;
          final noShow_     = (tok['noShow']           as int?)     ?? 0;
          final calcRate    = generated > 0 ? (served_ / generated * 100) : 0.0;
          final rate        = ((tok['consumptionRate'] as num?)     ?? calcRate).toDouble();
          final avgWait     = ((tok['avgWaitMinutes']  as num?)     ?? 0).toDouble();
          final peakWait    = ((tok['peakWaitMinutes'] as num?)     ?? 0).toDouble();
          final slow        = (tok['slowTokenCount']   as int?)     ?? 0;
          final buckets     = (tok['velocityBuckets']  as List?)    ?? [];

          final statusCards = [
            _TokStat('GENERATED', '$generated', _rev),
            _TokStat('SERVED',    '$served_',    _pos),
            _TokStat('PENDING',   '$pending_',   _warn),
            _TokStat('NO-SHOW',   '$noShow_',    _neg),
          ];

          final preparing_  = (tok['preparing'] as int?) ?? 0;
          final ready_      = (tok['ready']     as int?) ?? 0;

          final funnel = [
            _FunnelRow('Orders',    generated, generated, Colors.white),
            _FunnelRow('Preparing', preparing_, generated, _ord),
            _FunnelRow('Ready',     ready_,     generated, _warn),
            _FunnelRow('Collected', served_,    generated, _pos),
            _FunnelRow('No-show',   noShow_,    generated, _neg),
          ];

          final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Token lifecycle funnel', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('From order placed to pickup completed', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel)),
            const SizedBox(height: 16),
            Row(children: statusCards.map((s) => Expanded(child: Padding(padding: EdgeInsets.only(right: s == statusCards.last ? 0 : 8), child: s))).toList()),
            const SizedBox(height: 20),
            ...funnel,
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${rate.toStringAsFixed(0)}%', style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: rate >= 80 ? _pos : rate >= 50 ? _warn : _neg)),
                Text('consumption rate', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ])),
              Expanded(flex: 2, child: Column(children: [
                Container(height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
                  child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: rate / 100, child: Container(decoration: BoxDecoration(color: rate >= 80 ? _pos : rate >= 50 ? _warn : _neg, borderRadius: BorderRadius.circular(4))))),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('0%',   style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel, fontWeight: FontWeight.w600)),
                  Text('100%', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel, fontWeight: FontWeight.w600)),
                ]),
              ])),
            ]),
          ]);

          final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Token velocity & wait times', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Tokens served per 30-min window', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel)),
            const SizedBox(height: 16),
            if (buckets.isEmpty)
              const _EmptyText('No velocity data yet')
            else
              ...buckets.take(8).map((b) {
                final label = b['timeLabel'] as String;
                final count = b['count']     as int;
                final maxB  = buckets.map((x) => x['count'] as int).fold(0, (a, b_) => a > b_ ? a : b_);
                final h     = int.tryParse(label.split(':').first) ?? 12;
                final color = h >= 16 ? _units : h >= 12 ? _ord : _rev;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(width: 55, child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel, fontWeight: FontWeight.w600))),
                    Expanded(child: Container(height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(3)),
                      child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: maxB > 0 ? count / maxB : 0, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))))),
                    const SizedBox(width: 10),
                    SizedBox(width: 20, child: Text('$count', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: color), textAlign: TextAlign.right)),
                  ]),
                );
              }),
            const SizedBox(height: 16),
            _SecLabel('WAIT TIME STATS'),
            const SizedBox(height: 8),
            _WaitRow('Avg wait time',    '${avgWait.toStringAsFixed(1)} min'),
            _WaitRow('Peak wait',        '${peakWait.toStringAsFixed(1)} min'),
            _WaitRow('Tokens > 10 min',  '$slow items'),
          ]);

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
            child: isDesktop 
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: left),
                  Container(width: 1, height: 300, color: _divider, margin: const EdgeInsets.symmetric(horizontal: 24)),
                  Expanded(flex: 2, child: right),
                ])
              : Column(children: [
                  left,
                  const SizedBox(height: 24),
                  Divider(color: _divider),
                  const SizedBox(height: 24),
                  right,
                ]),
          );
        },
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6 — LINE GRAPH STATS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLineGraphSection(bool isDesktop, Map<String, dynamic> stats) {
    final sevenAsync = ref.watch(sevenDayStatsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SecLabel('TREND LINE GRAPHS — 7 DAY VIEW'),
      const SizedBox(height: 10),

      // Main multi-line graph
      _Card(
        title: 'Revenue & orders — 7 day trend',
        subtitle: 'Daily performance across the past week',
        child: sevenAsync.when(
          loading: () => _Shimmer(height: 200),
          error: (e, _) => _ErrorText(e.toString()),
          data: (seven) => _MultiLineGraph(data: seven, tabController: _graphTab),
        ),
      ),

      const SizedBox(height: 12),

      // Three smaller graphs
      Builder(builder: (_) {
        final small1 = _Card(title: 'Today vs yesterday — orders', subtitle: 'Hourly comparison', child: _TodayVsYesterdayChart(dateStr: _selectedDate, ref: ref));
        final small2 = _Card(title: 'Token consumption rate', subtitle: '% served per hour today',
          child: ref.watch(tokenConsumptionProvider((start: _selectedDate, end: _selectedDate))).when(
            loading: () => _Shimmer(height: 100),
            error: (e, st) => const _EmptyText('No data'),
            data: (tok) => _ConsumptionCurve(buckets: tok['velocityBuckets'] as List, total: tok['generated'] as int),
          ));

        final small3 = _Card(title: 'Revenue per session — 7 days', subtitle: 'Session revenue trend',
          child: SizedBox(height: 140, child: sevenAsync.when(
            loading: () => _Shimmer(height: 100),
            error: (e, st) => const _EmptyText('No data'),
            data: (seven) => _SessionRevenueCurve(data: seven),
          )));

        if (isDesktop) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: small1), const SizedBox(width: 12),
            Expanded(child: small2), const SizedBox(width: 12),
            Expanded(child: small3),
          ]);
        }
        return Column(children: [small1, const SizedBox(height: 12), small2, const SizedBox(height: 12), small3, const SizedBox(height: 12)]);
      }),

      const SizedBox(height: 12),

      // 7 day table (full width)
      sevenAsync.when(
        loading: () => _Shimmer(height: 200),
        error: (e, st) => const SizedBox.shrink(),
        data: (seven) => SizedBox(width: double.infinity, child: _Card(title: '7-day summary table', subtitle: 'Click any row to view that day', child: _SevenDayTable(data: seven))),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _Card({required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title,    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
        Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel, height: 1.2)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _KpiData {
  final String label, value, trend; final Color color; final List<double> history;
  const _KpiData(this.label, this.value, this.color, this.trend, [this.history = const []]);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final isUp  = data.trend.startsWith('+') || data.trend.contains('▲');
    final isNeg = data.trend.startsWith('-') || data.trend.contains('▼');
    final trendColor = isUp ? _pos : (isNeg ? _neg : _secLabel);
    final hist = data.history.isEmpty ? List.generate(8, (_) => 10.0) : data.history;
    final maxH = hist.fold(1.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: data.label == 'REVENUE' ? data.color.withValues(alpha: 0.5) : _cardBorder, 
          width: data.label == 'REVENUE' ? 1.5 : 1.0,
        ),
        boxShadow: data.label == 'REVENUE' ? [
          BoxShadow(color: data.color.withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 2),
        ] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        Text(data.label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: _secLabel, letterSpacing: .5)),
        const SizedBox(height: 12),
        // Big value number + trend
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(data.value, style: GoogleFonts.plusJakartaSans(
            fontSize: 38, fontWeight: FontWeight.w900, color: data.color, letterSpacing: -1.5, height: 1,
            shadows: data.label == 'REVENUE' ? [Shadow(color: data.color.withValues(alpha: 0.6), blurRadius: 12)] : null,
          )),
        ),
        if (data.trend.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Text(isUp ? '▲' : isNeg ? '▼' : '–', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: trendColor, fontWeight: FontWeight.w900, shadows: [Shadow(color: trendColor.withValues(alpha: 0.5), blurRadius: 8)])),
            const SizedBox(width: 4),
            Text(data.trend, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: trendColor, shadows: [Shadow(color: trendColor.withValues(alpha: 0.5), blurRadius: 8)])),
            const SizedBox(width: 6),
            Text('vs prev. period', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel, fontWeight: FontWeight.w500)),
          ]),
        ],
        // Push sparkline lower
        const Spacer(),
        // Sparkline bar graph at bottom
        SizedBox(
          height: 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: hist.asMap().entries.map((e) {
              final h = e.value;
              final isLast = e.key == hist.length - 1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    height: 28 * (maxH > 0 ? (h / maxH).clamp(0.08, 1.0) : 0.08),
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: isLast ? 1.0 : 0.22),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

class _TokStat extends StatelessWidget {
  final String label, value; final Color color;
  const _TokStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
    child: Column(children: [
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5, height: 1)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w800, color: _secLabel, letterSpacing: .3), textAlign: TextAlign.center),
    ]),
  );
}

class _FunnelRow extends StatelessWidget {
  final String label; final int value, total; final Color color;
  const _FunnelRow(this.label, this.value, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 72, child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel), textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        Expanded(child: Stack(alignment: Alignment.centerLeft, children: [
          Container(height: 26, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(5))),
          FractionallySizedBox(widthFactor: pct, child: Container(height: 26,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5), border: Border.all(color: color.withValues(alpha: 0.3))))),
          Padding(padding: const EdgeInsets.only(left: 10), child: Text('$value tokens', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
        ])),
        const SizedBox(width: 12),
        SizedBox(width: 28, child: Text('$value', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: color, fontWeight: FontWeight.w900), textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value; final Color color;
  const _MiniStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: color, height: 1)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _MicroStat extends StatelessWidget {
  final String label, value; final Color color;
  const _MicroStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}

class _BigStat extends StatelessWidget {
  final String value, label; final Color color;
  const _BigStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: color, height: 1)),
      const SizedBox(height: 3),
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _SessionMetricRow extends StatelessWidget {
  final String label, value; final Color color;
  const _SessionMetricRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _secLabel, fontWeight: FontWeight.w500)),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ],
  );
}


class _WaitRow extends StatelessWidget {
  final String label, value;
  const _WaitRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _secLabel)),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
    ]),
  );
}

class _PayRow extends StatelessWidget {
  final String label; final double value, total; final Color color;
  const _PayRow(this.label, this.value, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        SizedBox(width: 72, child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel))),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(3)),
          child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))))),
        const SizedBox(width: 8),
        SizedBox(width: 28, child: Text('${(pct*100).toStringAsFixed(0)}%', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String title, subtitle; final Color color;
  const _AlertRow(this.title, this.subtitle, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: color, width: 3))),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel)),
      ])),
      Text('now', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel)),
    ]),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _secLabel, fontWeight: FontWeight.w600)),
  ]);
}

class _SecLabel extends StatelessWidget {
  final String text; const _SecLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: _secLabel, letterSpacing: 1.2)));
}

class _Shimmer extends StatelessWidget {
  final double height; const _Shimmer({required this.height});
  @override
  Widget build(BuildContext context) => Container(height: height, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)));
}

class _EmptyText extends StatelessWidget {
  final String text; const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16),
    child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _secLabel), textAlign: TextAlign.center));
}

class _ErrorText extends StatelessWidget {
  final String text; const _ErrorText(this.text);
  @override
  Widget build(BuildContext context) => Text('Error: $text', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _neg));
}

// ── Category donut ───────────────────────────────────────────────────────────
class _CategoryDonut extends ConsumerStatefulWidget {
  final List<MapEntry<String, double>> entries;
  final Map<String, String> catNames;
  final double total;
  final List<Color> colors;
  const _CategoryDonut({required this.entries, required this.catNames, required this.total, required this.colors});
  @override
  ConsumerState<_CategoryDonut> createState() => _CategoryDonutState();
}
class _CategoryDonutState extends ConsumerState<_CategoryDonut> {
  int _touched = -1;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(height: 180, child: Stack(alignment: Alignment.center, children: [
        PieChart(PieChartData(
          pieTouchData: PieTouchData(touchCallback: (e, r) => setState(() {
            _touched = (!e.isInterestedForInteractions || r == null || r.touchedSection == null) ? -1 : r.touchedSection!.touchedSectionIndex;
          })),
          borderData: FlBorderData(show: false), sectionsSpace: 3, centerSpaceRadius: 55,
          sections: widget.entries.asMap().entries.map((e) => PieChartSectionData(
            color: widget.colors[e.key % widget.colors.length], value: e.value.value,
            title: '', radius: e.key == _touched ? 28.0 : 22.0,
          )).toList(),
        )),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            _touched == -1 ? 'Total' : (widget.catNames[widget.entries[_touched].key] ?? 'Category'),
            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _secLabel, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          Text(
            '₹${(_touched == -1 ? widget.total : widget.entries[_touched].value).toStringAsFixed(0)}',
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
          ),
        ]),
      ])),
      const SizedBox(height: 20),
      ...widget.entries.asMap().entries.map((e) {
         final color = widget.colors[e.key % widget.colors.length];
         final pct = widget.total > 0 ? (e.value.value / widget.total * 100) : 0.0;
         return Padding(
           padding: const EdgeInsets.only(bottom: 8),
           child: Row(children: [
             Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
             const SizedBox(width: 10),
             Expanded(child: Text(widget.catNames[e.value.key] ?? e.value.key, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _secLabel, fontWeight: FontWeight.w600))),
             Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.5))),
             const SizedBox(width: 12),
             SizedBox(width: 60, child: Text('₹${e.value.value.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: color), textAlign: TextAlign.right)),
           ]),
         );
      }),
    ]);
  }
}

// ── Multi-line 7-day graph ───────────────────────────────────────────────────
class _MultiLineGraph extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final TabController tabController;
  const _MultiLineGraph({required this.data, required this.tabController});
  @override
  State<_MultiLineGraph> createState() => _MultiLineGraphState();
}
class _MultiLineGraphState extends State<_MultiLineGraph> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final tabs = ['Both', 'Revenue', 'Orders', 'Tokens'];
    final revMax  = widget.data.map((d) => (d['revenue'] as num).toDouble()).fold(0.0, (a,b) => a>b?a:b);
    final ordMax  = widget.data.map((d) => (d['orders'] as int).toDouble()).fold(0.0, (a,b) => a>b?a:b);
    final scale   = revMax > 0 ? ordMax / revMax : 1.0;

    List<LineChartBarData> bars = [];
    if (_tab == 0 || _tab == 1) bars.add(_line(widget.data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble() * scale)).toList(), _rev));
    if (_tab == 0 || _tab == 2) bars.add(_line(widget.data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['orders'] as int).toDouble())).toList(), _ord));
    if (_tab == 0 || _tab == 3) bars.add(_line(widget.data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['served'] as int).toDouble())).toList(), _pos));

    return Column(children: [
      Row(children: tabs.asMap().entries.map((e) => GestureDetector(
        onTap: () => setState(() => _tab = e.key),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _tab == e.key ? _cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _tab == e.key ? Colors.white.withValues(alpha: 0.25) : Colors.transparent),
          ),
          child: Text(e.value, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: _tab == e.key ? Colors.white : _secLabel)),
        ),
      )).toList()),
      const SizedBox(height: 12),
      SizedBox(height: 180, child: LineChart(LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20, interval: 1,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= widget.data.length) {
                return const SizedBox.shrink();
              }
              final d = widget.data[i];
              final isToday = d['isToday'] == true;
              final label = isToday ? 'Today' : (d['displayDate'] as String).split(' ').first;
              return Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 8, color: isToday ? _rev : _secLabel, fontWeight: isToday ? FontWeight.w800 : FontWeight.w500));
            },
          )),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _cardBg,
            tooltipBorder: const BorderSide(color: _cardBorder),
            getTooltipItems: (spots) => spots.map((s) {
              final isRev = s.barIndex == 0 && (_tab == 0 || _tab == 1);
              final val = isRev && scale > 0 ? (s.y / scale) : s.y;
              final prefix = isRev ? '₹' : '';
              return LineTooltipItem('$prefix${val.toStringAsFixed(0)}', GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: s.bar.color ?? Colors.white));
            }).toList(),
          ),
        ),
        lineBarsData: bars,
        minX: 0, maxX: (widget.data.length - 1).toDouble(),
      ))),
    ]);
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots, isCurved: true, color: color, barWidth: 2, isStrokeCapRound: true,
    dotData: FlDotData(show: true, getDotPainter: (spot, a, b, i) => FlDotCirclePainter(
      radius: i == spots.length - 1 ? 5 : 3,
      color: i == spots.length - 1 ? color : Colors.transparent,
      strokeWidth: 2, strokeColor: color,
    )),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
  );
}

// ── Today vs yesterday chart ─────────────────────────────────────────────────
class _TodayVsYesterdayChart extends ConsumerWidget {
  final String dateStr;
  final WidgetRef ref;
  const _TodayVsYesterdayChart({required this.dateStr, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today     = ref.watch(statsByPeriodProvider((start: dateStr, end: dateStr)));
    final prevDay   = DateFormat('yyyy-MM-dd').format(DateFormat('yyyy-MM-dd').parse(dateStr).subtract(const Duration(days: 1)));
    final yesterday = ref.watch(statsByPeriodProvider((start: prevDay, end: prevDay)));

    List<FlSpot> toSpots(Map<dynamic, dynamic> h) {
      final spots = <FlSpot>[];
      for (int i = 8; i <= 20; i++) { spots.add(FlSpot((i - 8).toDouble(), ((h[i] ?? h['$i'] ?? 0) as num).toDouble())); }
      return spots;
    }

    final todayH = today['hourlyOrders'] as Map<dynamic, dynamic>? ?? {};
    final yestH  = yesterday['hourlyOrders'] as Map<dynamic, dynamic>? ?? {};

    return SizedBox(height: 120, child: LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 16, interval: 1,
          getTitlesWidget: (v, _) {
            final h = v.toInt() + 8;
            final isPM = h >= 12; final dh = h > 12 ? (h == 24 ? 12 : h - 12) : h;
            return Text('$dh${isPM?'p':'a'}', style: GoogleFonts.plusJakartaSans(fontSize: 8, color: _secLabel));
          },
        )),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _cardBg,
          tooltipBorder: const BorderSide(color: _cardBorder),
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
            s.y.toStringAsFixed(0), GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: s.bar.color ?? Colors.white),
          )).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(spots: toSpots(todayH), isCurved: true, color: _rev, barWidth: 2, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: _rev.withValues(alpha: 0.08))),
        LineChartBarData(spots: toSpots(yestH),  isCurved: true, color: _rev.withValues(alpha: 0.35), barWidth: 1.5, dotData: const FlDotData(show: false), dashArray: [4, 4]),
      ],
      minX: 0, maxX: 12,
    )));
  }
}

// ── Session revenue curve ────────────────────────────────────────────────────
class _SessionRevenueCurve extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _SessionRevenueCurve({required this.data});
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyText('No data yet');
    }

    final reversed = data.reversed.toList();
    final spotsBF = <FlSpot>[];
    final spotsLUN = <FlSpot>[];
    final spotsEVE = <FlSpot>[];

    for (int i = 0; i < reversed.length; i++) {
       final hw = reversed[i]['hourlyOrders'] as Map<dynamic, dynamic>? ?? {};
       int bf = 0; int lun = 0; int eve = 0;
       hw.forEach((k, v) {
         final h = int.tryParse(k.toString()) ?? 0;
         final count = (v as num).toInt();
          if (h < 12) {
            bf += count;
          } else if (h < 16) {
            lun += count;
          } else {
            eve += count;
          }
       });
       spotsBF.add(FlSpot(i.toDouble(), bf.toDouble()));
       spotsLUN.add(FlSpot(i.toDouble(), lun.toDouble()));
       spotsEVE.add(FlSpot(i.toDouble(), eve.toDouble()));
    }

    LineChartBarData line(List<FlSpot> spots, Color color) => LineChartBarData(
      spots: spots, isCurved: true, color: color, barWidth: 1.5,
      dotData: const FlDotData(show: false),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _LegendDot(color: _rev, label: 'BF'), const SizedBox(width: 8),
        _LegendDot(color: _ord, label: 'LUN'), const SizedBox(width: 8),
        _LegendDot(color: _units, label: 'EVE'),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20, interval: 1, getTitlesWidget: (value, meta) {
               if (value.toInt() >= reversed.length || value.toInt() < 0) {
                 return const SizedBox.shrink();
               }
               final d = reversed[value.toInt()];
               final isToday = d['isToday'] == true;
               final label = isToday ? 'Today' : (d['displayDate'] as String).split(' ').first;
               return Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 8, color: isToday ? _rev : _secLabel, fontWeight: isToday ? FontWeight.w800 : FontWeight.w500));
            })),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => _cardBg,
              tooltipBorder: const BorderSide(color: _cardBorder),
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '₹${s.y.toStringAsFixed(0)}', GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: s.bar.color ?? Colors.white),
              )).toList(),
            ),
          ),
          lineBarsData: [line(spotsBF, _rev), line(spotsLUN, _ord), line(spotsEVE, _units)],
        )),
      ),
    ]);
  }
}

// ── Consumption curve ────────────────────────────────────────────────────────
class _ConsumptionCurve extends StatelessWidget {
  final List buckets; final int total;
  const _ConsumptionCurve({required this.buckets, required this.total});
  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty || total == 0) {
      return const _EmptyText('No data yet');
    }
    int cumulative = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < buckets.length; i++) {
      cumulative += (buckets[i]['count'] as int);
      spots.add(FlSpot(i.toDouble(), (cumulative / total * 100).clamp(0.0, 100.0)));
    }
    return SizedBox(height: 120, child: LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 16, interval: 1,
          getTitlesWidget: (v, _) {
            final h = v.toInt() + 8;
            final isPM = h >= 12; final dh = h > 12 ? (h == 24 ? 12 : h - 12) : h;
            return Text('$dh${isPM?'p':'a'}', style: GoogleFonts.plusJakartaSans(fontSize: 8, color: _secLabel));
          },
        )),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _cardBg,
          tooltipBorder: const BorderSide(color: _cardBorder),
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
            '${s.y.toStringAsFixed(0)}%', GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: s.bar.color ?? Colors.white),
          )).toList(),
        ),
      ),
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true, color: _pos, barWidth: 2,
        dotData: FlDotData(show: true, getDotPainter: (spot, a, b, i) => FlDotCirclePainter(
          radius: i == spots.length - 1 ? 5 : 0, color: _pos, strokeWidth: 0, strokeColor: _pos)),
        belowBarData: BarAreaData(show: true, color: _pos.withValues(alpha: 0.1)),
      )],
      minX: 0, maxX: (spots.length - 1).toDouble(), minY: 0, maxY: 100,
    )));
  }
}

// ── 7-day table ───────────────────────────────────────────────────────────────
class _SevenDayTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _SevenDayTable({required this.data});

  @override
  Widget build(BuildContext context) {
    TextStyle head(String t) => GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: _secLabel, letterSpacing: .5);
    TextStyle cell(String t, {Color? color, bool bold = false}) =>
        GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? Colors.white);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - (MediaQuery.of(context).size.width > 900 ? 116 : 68)),
        child: Table(
          defaultColumnWidth: const FlexColumnWidth(),
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _divider))),
              children: ['DATE','REVENUE','ORDERS','SERVED','NO-SHOW','AVG WAIT','WASTE ₹','VS PREV']
                  .map((h) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(h, style: head(h)))).toList(),
            ),
          ...data.asMap().entries.map((e) {
            final d       = e.value;
            final isToday = d['isToday'] == true;
            final prev    = e.key > 0 ? data[e.key - 1] : null;
            final prevRev = prev != null ? ((prev['revenue'] as num?) ?? 0).toDouble() : 0.0;
            final curRev  = ((d['revenue'] as num?) ?? 0).toDouble();
            final chg     = prevRev > 0 ? ((curRev - prevRev) / prevRev * 100) : 0.0;
            final chgStr  = prev == null ? '—' : '${chg >= 0 ? '▲' : '▼'} ${chg.abs().toStringAsFixed(1)}%';
            final chgColor = chg >= 0 ? _pos : _neg;
            return TableRow(
              decoration: BoxDecoration(
                color: isToday ? _rev.withValues(alpha: 0.06) : Colors.transparent,
                border: Border(bottom: BorderSide(color: _divider, width: 0.5)),
              ),
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(0,8,20,8), child: Text(d['displayDate'] as String, style: cell('', color: isToday ? _rev : _secLabel, bold: isToday))),
                Padding(padding: const EdgeInsets.fromLTRB(0,8,20,8), child: Text('₹${((d['revenue'] as num?) ?? 0).toStringAsFixed(0)}', style: cell('', color: isToday ? _rev : Colors.white, bold: isToday))),
                Padding(padding: const EdgeInsets.fromLTRB(0,8,20,8), child: Text('${d['orders'] ?? 0}', style: cell('', bold: isToday))),
                Padding(padding: const EdgeInsets.fromLTRB(0,8,20,8), child: Text('${d['served'] ?? 0}', style: cell('', color: _pos, bold: isToday))),
                Padding(padding: const EdgeInsets.fromLTRB(0,8,20,8), child: Text('${d['noShow'] ?? 0}',  style: cell('', color: _neg))),
                Padding(padding: const EdgeInsets.fromLTRB(0,8,20,8), child: Text('${((d['avgWait'] as num?) ?? 0).toStringAsFixed(1)}m', style: cell(''))),
                Padding(padding: const EdgeInsets.fromLTRB(0,8,20,8), child: Text('₹${((d['wasteValue'] as num?) ?? 0).toStringAsFixed(0)}', style: cell('', color: _warn))),
                Padding(padding: const EdgeInsets.fromLTRB(0,8,0,8),  child: Text(chgStr, style: cell('', color: prev == null ? _secLabel : chgColor))),
              ],
            );
          }),
        ],
      ),
      ),
    );
  }
}

// ── cartBehaviourProvider (local, derived) ───────────────────────────────────
final cartBehaviourProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, dateStr) async {
  final stats = ref.watch(statsByPeriodProvider((start: dateStr, end: dateStr)));
  final orders = (stats['totalOrders'] ?? 0) as int;
  final units  = (stats['totalItemsSold'] ?? 0) as int;
  final rev    = (stats['totalRevenue'] ?? 0) as num;
  return {
    'avgItemsPerOrder': orders > 0 ? units / orders : 0.0,
    'avgOrderValue':    orders > 0 ? rev  / orders : 0.0,
  };
});
