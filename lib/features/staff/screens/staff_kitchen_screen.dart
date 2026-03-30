import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/themes/staff_theme.dart';
import '../providers/staff_providers.dart';

class StaffKitchenScreen extends ConsumerWidget {
  const StaffKitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Professional light grey background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref),
            _buildPrepStats(ref),
            _buildTabs(context, ref),
            _buildSlotChips(ref),
            Expanded(child: _buildKitchenList(ref)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrepStats(WidgetRef ref) {
    final aggregated = ref.watch(kitchenAggregationProvider);
    final total = aggregated['totalDemand'] ?? 0;
    final pending = aggregated['pendingPrep'] ?? 0;
    final ready = total - pending;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem('TOTAL ORDERS', '$total', Icons.receipt_long_outlined, Colors.blue),
            Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
            _buildStatItem('PENDING PREP', '$pending', Icons.outdoor_grill_outlined, const Color(0xFFEF4444)),
            Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
            _buildStatItem('READY', '$ready', Icons.check_circle_outline, const Color(0xFF22C55E)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: StaffTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.soup_kitchen_rounded, color: StaffTheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kitchen Pulse',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, MMM dd').format(DateTime.now()),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showSummaryDialog(context, ref),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      'REPORT',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog(BuildContext context, WidgetRef ref) {
    final aggregatedData = ref.watch(kitchenAggregationProvider);
    final categoriesMap = aggregatedData['categories'] as Map<String, dynamic>;
    
    final List<Map<String, dynamic>> itemsList = [];
    categoriesMap.values.forEach((cat) {
      final items = cat['items'] as Map<String, dynamic>;
      items.values.forEach((item) => itemsList.add(item));
    });
    
    itemsList.sort((a, b) {
      final remA = (a['orderedQty'] as int) - (a['preparedQty'] as int);
      final remB = (b['orderedQty'] as int) - (b['preparedQty'] as int);
      return remB.compareTo(remA);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Text(
                'Production Guide',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, 
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'REMAINING QUANTITIES TO PREPARE',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900, 
                    fontSize: 11, 
                    color: StaffTheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                ...itemsList.map((item) {
                  final rem = (item['orderedQty'] as int) - (item['preparedQty'] as int);
                  if (rem <= 0) return const SizedBox.shrink();
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name'],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, 
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$rem',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, 
                              fontWeight: FontWeight.w900, 
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ensure all current session batches are completed before starting upcoming slot prep.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, 
                            color: const Color(0xFF9A3412), 
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(
                    'DISMISS',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800, 
                      color: const Color(0xFF64748B),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preparing Production PDF...')),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text(
                    'EXPORT GUIDE',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(staffKitchenTabProvider);
    final tabs = [
      {'id': 'current', 'label': 'Live Session', 'icon': Icons.bolt_rounded},
      {'id': 'upcoming', 'label': 'Next Batch', 'icon': Icons.schedule_rounded},
      {'id': 'fullday', 'label': 'Daily View', 'icon': Icons.calendar_today_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = activeTab == tab['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  ref.read(staffKitchenTabProvider.notifier).state = tab['id'] as String;
                  ref.read(staffKitchenSelectedSlotIdProvider.notifier).state = null;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ] : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab['icon'] as IconData, 
                        size: 16, 
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B)
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab['label'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSlotChips(WidgetRef ref) {
    final activeTab = ref.watch(staffKitchenTabProvider);
    if (activeTab == 'fullday') return const SizedBox.shrink();

    final slotsAsync = ref.watch(staffSessionSlotsProvider);
    final selectedSlotId = ref.watch(staffKitchenSelectedSlotIdProvider);

    return slotsAsync.when(
      data: (slots) {
        if (slots.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: slots.length + 1,
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final slotId = isAll ? null : slots[index - 1]['id'];
              final isSelected = selectedSlotId == slotId;
              final label = isAll ? 'ALL ORDERED' : '${slots[index - 1]['startTime'] as String} - ${slots[index - 1]['endTime'] as String}';
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => ref.read(staffKitchenSelectedSlotIdProvider.notifier).state = slotId,
                  backgroundColor: Colors.white,
                  selectedColor: StaffTheme.primary.withValues(alpha: 0.1),
                  checkmarkColor: StaffTheme.primary,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? StaffTheme.primary : const Color(0xFF64748B),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isSelected ? StaffTheme.primary : const Color(0xFFE2E8F0)),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildKitchenList(WidgetRef ref) {
    final aggregatedData = ref.watch(kitchenAggregationProvider);
    final categoriesMap = aggregatedData['categories'] as Map<String, dynamic>;
    final highDemand = aggregatedData['highDemand'] as List<Map<String, dynamic>>;

    if (categoriesMap.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(Icons.restaurant_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            Text(
              'No Preparation Needed',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF475569),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Wait for fresh orders to arrive.',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final categoriesList = categoriesMap.values.toList();

    return Scrollbar(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          if (highDemand.isNotEmpty) _buildHighDemandSection(ref, highDemand),
          ...categoriesList.map((category) => _buildCategorySection(ref, category)),
        ],
      ),
    );
  }

  Widget _buildHighDemandSection(WidgetRef ref, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF97316), size: 20),
            const SizedBox(width: 8),
            Text(
              'URGENT PREP LIST',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final rem = (item['orderedQty'] as int) - (item['preparedQty'] as int);
              if (rem <= 0 && index == 0 && items.length > 1) return const SizedBox.shrink();

              return Container(
                width: 220,
                margin: const EdgeInsets.only(right: 16, bottom: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$rem',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            Text(
                              'TO PREP',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white54,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            rem > 10 ? Icons.priority_high_rounded : Icons.trending_up, 
                            color: rem > 10 ? const Color(0xFFF97316) : Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCategorySection(WidgetRef ref, dynamic category) {
    final title = category['categoryName'] as String;
    final itemsMap = category['items'] as Map<String, dynamic>;
    final itemsList = itemsMap.values.toList();
    
    itemsList.sort((a, b) {
      final remA = (a['orderedQty'] as int) - (a['preparedQty'] as int);
      final remB = (b['orderedQty'] as int) - (b['preparedQty'] as int);
      return remB.compareTo(remA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(width: 12, height: 2, color: _getCategoryColor(title)),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        ...itemsList.map((item) => _buildPrepCard(ref, item)).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Color _getCategoryColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('wrap') || n.contains('main')) return const Color(0xFF10B981);
    if (n.contains('drink') || n.contains('juice')) return const Color(0xFF3B82F6);
    if (n.contains('snack')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  Widget _buildPrepCard(WidgetRef ref, dynamic item) {
    final name = item['name'] as String;
    final orderedQty = item['orderedQty'] as int;
    final preparedQty = item['preparedQty'] as int;
    final isPreReady = item['isPreReady'] as bool? ?? false;
    final remaining = orderedQty - preparedQty;
    final progress = orderedQty > 0 ? (preparedQty / orderedQty) : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isPreReady ? const Color(0xFFF1F5F9) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPreReady ? Icons.inventory_2_outlined : _getItemIcon(name),
                    color: isPreReady ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                    size: 22,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPreReady ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPreReady ? 'READY-TO-SERVE' : 'REQUIRES PREP',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: isPreReady ? const Color(0xFF475569) : const Color(0xFF166534),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$remaining',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: remaining > 0 ? (isPreReady ? const Color(0xFF64748B) : const Color(0xFFEF4444)) : const Color(0xFF10B981),
                      ),
                    ),
                    Text(
                      'REMAINING',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0 ? const Color(0xFF10B981) : (isPreReady ? const Color(0xFF94A3B8) : StaffTheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$preparedQty/$orderedQty',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getItemIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('wrap') || n.contains('roll')) return Icons.restaurant_menu_rounded;
    if (n.contains('drink') || n.contains('juice') || n.contains('coffee')) return Icons.local_cafe_rounded;
    if (n.contains('bowl') || n.contains('salad')) return Icons.flatware_rounded;
    return Icons.inventory_2_outlined;
  }
}
