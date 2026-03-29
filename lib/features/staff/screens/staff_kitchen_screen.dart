import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/themes/staff_theme.dart';
import '../providers/staff_providers.dart';

class StaffKitchenScreen extends ConsumerWidget {
  const StaffKitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: StaffTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref),
            const SizedBox(height: 8),
            _buildTabs(context, ref),
            _buildSlotChips(ref),
            const Divider(height: 1, color: StaffTheme.border),
            Expanded(child: _buildKitchenList(ref)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(staffKitchenTabProvider);
    String subtitle = 'Inventory & Planning';
    if (activeTab == 'upcoming') subtitle = 'Upcoming Session';
    if (activeTab == 'fullday') subtitle = 'Full Day Overview';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kitchen Prep',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: StaffTheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: StaffTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => _showSummaryDialog(context, ref),
            icon: const Icon(Icons.file_download_outlined, size: 20),
            label: Text(
              'SUMMARY',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
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

    final topPriorities = itemsList.take(5).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StaffTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.analytics_outlined, color: StaffTheme.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Kitchen Summary',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Preparation Priorities',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: StaffTheme.primary),
              ),
              const SizedBox(height: 12),
              if (topPriorities.isEmpty)
                Text('No active prep items.', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey))
              else
                ...topPriorities.map((item) {
                  final rem = (item['orderedQty'] as int) - (item['preparedQty'] as int);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: rem > 20 ? Colors.red : StaffTheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['name'],
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '$rem left',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: StaffTheme.statusSkipped, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Focus on high-volume items with low prep progress to optimize throughput.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: StaffTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report generation started...')),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('DOWNLOAD PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(staffKitchenTabProvider);
    final tabs = [
      {'id': 'current', 'label': 'Current Session'},
      {'id': 'upcoming', 'label': 'Upcoming'},
      {'id': 'fullday', 'label': 'Full Day'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: StaffTheme.border),
        ),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = activeTab == tab['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  ref.read(staffKitchenTabProvider.notifier).state = tab['id']!;
                  ref.read(staffKitchenSelectedSlotIdProvider.notifier).state = null; // Reset slot filter
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? StaffTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      tab['label']!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
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
          height: 54,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: slots.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // Return "ALL" Chip
                final isSelected = selectedSlotId == null;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: InkWell(
                    onTap: () {
                      ref.read(staffKitchenSelectedSlotIdProvider.notifier).state = null;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? StaffTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? StaffTheme.primary : StaffTheme.border,
                          width: 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: StaffTheme.primary.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'ALL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final slot = slots[index - 1];
              final id = slot['id'];
              final isSelected = selectedSlotId == id;
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: InkWell(
                  onTap: () {
                    if (isSelected) {
                      ref.read(staffKitchenSelectedSlotIdProvider.notifier).state = null;
                    } else {
                      ref.read(staffKitchenSelectedSlotIdProvider.notifier).state = id;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green.shade400 : StaffTheme.border,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${slot['startTime']} - ${slot['endTime']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 54, child: Center(child: LinearProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildKitchenList(WidgetRef ref) {
    final activeTab = ref.watch(staffKitchenTabProvider);
    final aggregatedData = ref.watch(kitchenAggregationProvider);
    final categoriesMap = aggregatedData['categories'] as Map<String, dynamic>;
    final highDemand = aggregatedData['highDemand'] as List<Map<String, dynamic>>;

    if (categoriesMap.isEmpty) {
      String message = 'No preparation demand yet.';
      if (activeTab == 'current') message = 'No orders in current session.';
      if (activeTab == 'upcoming') message = 'No upcoming session demand.';
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final categoriesList = categoriesMap.values.toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        if (highDemand.isNotEmpty) _buildHighDemandSection(ref, highDemand),
        ...categoriesList.map((category) => _buildCategorySection(ref, category)),
      ],
    );
  }

  Widget _buildHighDemandSection(WidgetRef ref, List<Map<String, dynamic>> items) {
    final activeTab = ref.watch(staffKitchenTabProvider);
    final isFullDay = activeTab == 'fullday';
    final title = isFullDay ? 'HIGH DEMAND TODAY' : 'HIGH DEMAND ITEMS';
    final icon = isFullDay ? Icons.trending_up_rounded : Icons.warning_amber_rounded;
    final iconColor = isFullDay ? const Color(0xFF166534) : const Color(0xFFD97706);
    final bgColor = isFullDay ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED);
    final borderColor = isFullDay ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5);
    final textColor = isFullDay ? const Color(0xFF166534) : const Color(0xFF92400E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final label = item['label'] ?? 'High';
                      final isPeak = label == 'Peak';

                      return Container(
                        width: 190,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item['orderedQty']}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: StaffTheme.textPrimary,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isPeak ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isPeak ? const Color(0xFF166534) : const Color(0xFFD97706),
                                    ),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategorySection(WidgetRef ref, dynamic category) {
    final activeTab = ref.watch(staffKitchenTabProvider);
    final title = category['categoryName'] as String;
    final totalQty = category['totalQty'] as int;
    final itemsMap = category['items'] as Map<String, dynamic>;
    final itemsList = itemsMap.values.toList();
    final countSuffix = activeTab == 'fullday' ? 'Daily Total' : 'Items';

    itemsList.sort(
      (a, b) => (b['orderedQty'] as int).compareTo(a['orderedQty'] as int),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(title),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: StaffTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalQty $countSuffix',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: itemsList.map((item) => _buildPrepCard(ref, item)).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Color _getCategoryColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('wrap') || n.contains('main')) return const Color(0xFF166534);
    if (n.contains('drink') || n.contains('juice') || n.contains('coffee')) return const Color(0xFF3B82F6);
    if (n.contains('snack') || n.contains('sides')) return const Color(0xFFF59E0B);
    return Colors.black;
  }

  Widget _buildPrepCard(WidgetRef ref, dynamic item) {
    final activeTab = ref.watch(staffKitchenTabProvider);
    final name = item['name'] as String;
    final orderedQty = item['orderedQty'] as int;
    final preparedQty = item['preparedQty'] as int;
    final progress = orderedQty > 0 ? (preparedQty / orderedQty) : 0.0;
    
    final labelTitle = activeTab == 'fullday' ? 'Daily Target' : 'Regular';
    final progressLabel = activeTab == 'fullday' ? 'PREP PROGRESS (DAILY)' : 'PREP PROGRESS';
    final qtyLabel = activeTab == 'fullday' ? 'TOTAL QTY' : 'QTY';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StaffTheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: StaffTheme.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: Icon(
                    _getItemIcon(name), 
                    color: Colors.white, 
                    size: 26
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      labelTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                    '$orderedQty',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    qtyLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progressLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$preparedQty / $orderedQty',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 
                    ? StaffTheme.secondary // Bright Green on Dark Green
                    : (progress > 0.5 ? StaffTheme.secondary.withValues(alpha: 0.8) : const Color(0xFFF97316)), // Secondary or Orange
              ),
            ),
          ),
        ],
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
