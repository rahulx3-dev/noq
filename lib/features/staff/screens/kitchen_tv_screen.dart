import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/staff_providers.dart';

class KitchenTvScreen extends ConsumerStatefulWidget {
  const KitchenTvScreen({super.key});

  @override
  ConsumerState<KitchenTvScreen> createState() => _KitchenTvScreenState();
}

class _KitchenTvScreenState extends ConsumerState<KitchenTvScreen> {
  final Color stitchPrimary = const Color(0xFF13EC22);
  final Color stitchBgLight = const Color(0xFFF6F8F6);
  final Color stitchBgDark = const Color(0xFF102212);

  // Slate palette
  final Color slate900 = const Color(0xFF0F172A);
  final Color slate800 = const Color(0xFF1E293B);
  final Color slate500 = const Color(0xFF64748B);
  final Color slate400 = const Color(0xFF94A3B8);
  final Color slate300 = const Color(0xFFCBD5E1);
  final Color slate200 = const Color(0xFFE2E8F0);
  final Color slate100 = const Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(todayAllOrdersStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? stitchBgDark : stitchBgLight,
      body: ref.watch(currentDaySessionsWithStatusProvider).when(
        data: (sessions) {
          // Identify Truly Live Session
          final liveSession = sessions.firstWhere(
            (s) => s['isLive'] == true,
            orElse: () => {},
          );
          final liveSessionId = liveSession['id'] as String?;
          final sessionName = liveSession['name'] as String? ?? 'NO ACTIVE SESSION';

          return Column(
            children: [
              _buildHeader(isDark, sessionName),
              Expanded(
                child: liveSessionId == null
                    ? _buildPausedState(isDark)
                    : ordersAsync.when(
                        data: (docs) {
                          final prepOrders = <Map<String, dynamic>>[];
                          final readyOrders = <Map<String, dynamic>>[];
                          final calledOrders = <Map<String, dynamic>>[];

                          final activeStatuses = [
                            'pending',
                            'preparing',
                            'ready',
                            'partial',
                            'partial served',
                            'skipped',
                          ];

                          for (final doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            data['id'] = doc.id;

                            // RULE: Filter by detected live sessionId
                            if (data['sessionId'] != liveSessionId) continue;

                            final status = (data['orderStatus'] as String?)?.toLowerCase() ?? 'pending';
                            final isCalled = data['isCalledForPickup'] == true;

                            if (activeStatuses.contains(status)) {
                              if (isCalled) {
                                calledOrders.add(data);
                              } else if (status == 'ready') {
                                readyOrders.add(data);
                              } else {
                                prepOrders.add(data);
                              }
                            }
                          }
                          
                          // Sort by token number
                          prepOrders.sort((a, b) {
                            final aNum = int.tryParse(a['tokenNumber']?.toString() ?? '0') ?? 0;
                            final bNum = int.tryParse(b['tokenNumber']?.toString() ?? '0') ?? 0;
                            return aNum.compareTo(bNum);
                          });
                          readyOrders.sort((a, b) {
                            final aNum = int.tryParse(a['tokenNumber']?.toString() ?? '0') ?? 0;
                            final bNum = int.tryParse(b['tokenNumber']?.toString() ?? '0') ?? 0;
                            return aNum.compareTo(bNum);
                          });
                          calledOrders.sort((a, b) {
                            final aNum = int.tryParse(a['tokenNumber']?.toString() ?? '0') ?? 0;
                            final bNum = int.tryParse(b['tokenNumber']?.toString() ?? '0') ?? 0;
                            return aNum.compareTo(bNum);
                          });

                          return Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildQueueColumn(
                                    title: 'PREPARING',
                                    icon: Icons.outdoor_grill,
                                    iconColor: Colors.orange,
                                    count: prepOrders.length,
                                    orders: prepOrders,
                                    isReadyColumn: false,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildQueueColumn(
                                    title: 'READY',
                                    icon: Icons.notifications_paused,
                                    iconColor: stitchPrimary.withValues(alpha: 0.8),
                                    count: readyOrders.length,
                                    orders: readyOrders,
                                    isReadyColumn: true,
                                    isDark: isDark,
                                    isCalledColumn: false,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildQueueColumn(
                                    title: 'CALLED TOKENS',
                                    icon: Icons.campaign,
                                    iconColor: stitchPrimary,
                                    count: calledOrders.length,
                                    orders: calledOrders,
                                    isReadyColumn: true,
                                    isDark: isDark,
                                    isCalledColumn: true,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Center(child: Text('Error: $e')),
                      ),
              ),
              _buildFooter(isDark),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(bool isDark, String sessionName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: stitchPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.restaurant, color: stitchPrimary, size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Live Kitchen Queue',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: stitchPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: stitchPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          sessionName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: stitchPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'noq Food Ordering System',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Current Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StreamBuilder<DateTime>(
                stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                builder: (context, snapshot) {
                  final time = snapshot.data ?? DateTime.now();
                  return Text(
                    DateFormat('hh:mm a').format(time),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: stitchPrimary,
                    ),
                  );
                },
              ),
              Text(
                'CURRENT SYSTEM TIME',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPausedState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pause_circle_filled,
              size: 120,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'SERVICE PAUSED',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'NO SESSIONS ARE CURRENTLY LIVE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: slate500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: stitchPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: stitchPrimary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Text(
                  'Waiting for Admin to release next session...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueColumn({
    required String title,
    required IconData icon,
    required Color iconColor,
    required int count,
    required List<Map<String, dynamic>> orders,
    required bool isReadyColumn,
    required bool isDark,
    bool isCalledColumn = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count Orders',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final order = orders[index];
              return isReadyColumn ? _buildReadyCard(order, isDark, isCalledColumn) : _buildPreparingCard(order, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreparingCard(Map<String, dynamic> order, bool isDark) {
    final token = order['tokenNumber']?.toString() ?? '--';
    final studentName = order['userNameSnapshot'] ?? order['customerName'] ?? 'Student';
    final status = (order['orderStatus'] as String?)?.toUpperCase() ?? 'PENDING';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Token #$token',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    studentName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: slate500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status == 'PREPARING' ? 'IN PROGRESS' : status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadyCard(Map<String, dynamic> order, bool isDark, [bool isCalledColumn = false]) {
    final token = order['tokenNumber']?.toString() ?? '--';
    final studentName = order['userNameSnapshot'] ?? order['customerName'] ?? 'Student';
    
    final bgColor = isCalledColumn ? Colors.orange : stitchPrimary;
    final shadowColor = isCalledColumn ? Colors.orange.withValues(alpha: 0.3) : stitchPrimary.withValues(alpha: 0.3);
    final bottomText = isCalledColumn ? 'NOW SERVING - COME TO COUNTER' : 'READY - WAIT FOR CALL';
    final iconData = isCalledColumn ? Icons.campaign : Icons.celebration;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Icon
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.check_circle,
              size: 140,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$token',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        studentName.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: Colors.white, size: 36),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Box at bottom with explicit instructions
              Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      bottomText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: bgColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: const Color(0xFF0F172A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: stitchPrimary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('System Online', style: TextStyle(color: slate500, fontSize: 12)),
                ],
              ),
              const SizedBox(width: 24),
              Icon(Icons.wifi, color: slate500, size: 14),
              const SizedBox(width: 8),
              Text('Kitchen-Network-5G', style: TextStyle(color: slate500, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              Text(
                'Last Updated: ${DateFormat('hh:mm:ss a').format(DateTime.now())}',
                style: TextStyle(color: slate500, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: slate800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'v4.2.0',
                  style: TextStyle(color: slate500, fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
