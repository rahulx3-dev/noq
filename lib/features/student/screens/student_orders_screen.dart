import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/app_routes.dart';
import '../../../app/themes/student_theme.dart';
import '../providers/student_orders_provider.dart';
// import '../../../core/utils/time_helper.dart';

class StudentOrdersScreen extends ConsumerStatefulWidget {
  const StudentOrdersScreen({super.key});

  @override
  ConsumerState<StudentOrdersScreen> createState() =>
      _StudentOrdersScreenState();
}

class _StudentOrdersScreenState extends ConsumerState<StudentOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: _isSearching ? 0 : 24,
        title: _isSearching
            ? Container(
                height: 44,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by token #',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF9CA3AF)),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchController.clear();
                        });
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              )
            : Text(
                'Orders',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
        actions: _isSearching
            ? []
            : [
                GestureDetector(
                  onTap: () => setState(() => _isSearching = true),
                  child: _buildAppBarAction(Icons.search),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => context.push('/student/notifications'),
                  child: _buildAppBarAction(Icons.notifications_none_rounded),
                ),
                const SizedBox(width: 20),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorColor: Colors.black,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black,
              unselectedLabelColor: const Color(0xFF717171),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(true),
          _buildOrdersList(false),
        ],
      ),
    );
  }

  Widget _buildAppBarAction(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Icon(icon, color: Colors.black, size: 22),
    );
  }

  Widget _buildOrdersList(bool isActive) {
    final streamAsync = ref.watch(studentOrdersStreamProvider);

    return streamAsync.when(
      data: (_) {
        final allOrders = isActive
            ? ref.watch(studentActiveOrdersProvider)
            : ref.watch(studentOrderHistoryProvider);

        // Filter by token
        final query = _searchController.text.toLowerCase();
        final orders = allOrders.where((o) {
          final token = (o['tokenNumber'] ?? '').toString().toLowerCase();
          return token.contains(query);
        }).toList();

        if (orders.isEmpty) {
          return _buildEmptyState(isActive);
        }

        // Group by date
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var order in orders) {
          DateTime date = DateTime.now();
          final createdAt = order['createdAt'];
          if (createdAt is Timestamp) {
            date = createdAt.toDate();
          } else if (createdAt is DateTime) {
            date = createdAt;
          }
          
          final dateStr = DateFormat('MMMM dd').format(date).toUpperCase();
          grouped.putIfAbsent(dateStr, () => []).add(order);
        }

        final sortedDates = grouped.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final dateKey = sortedDates[index];
            final dateOrders = grouped[dateKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    dateKey,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9CA3AF),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                ...dateOrders.map((order) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildOrderCard(order),
                )),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
      error: (err, _) {
        final errorStr = err.toString().toLowerCase();
        if (errorStr.contains('network') || errorStr.contains('unavailable')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(AppRoutes.studentNoNetwork);
            }
          });
          return const SizedBox.shrink();
        }
        return Center(child: Text('Error: $err'));
      },
    );
  }

  Widget _buildEmptyState(bool isActive) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            isActive ? 'No active orders' : 'No order history',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade400,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No match for "${_searchController.text}"',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final token = order['tokenNumber'] ?? 'XXXX';
    final status = order['orderStatus'] as String? ?? 'pending';
    final List<dynamic> items;
    final double total;
    DateTime placedOn = DateTime.now();

    if (order['isAggregated'] == true) {
      final List<Map<String, dynamic>> subOrders = List<Map<String, dynamic>>.from(order['subOrders'] ?? []);
      items = subOrders.expand((o) => o['items'] as List<dynamic>? ?? []).toList();
      total = subOrders.fold(0.0, (acc, o) => acc + (o['totalAmount'] ?? 0.0));
      final createdAt = order['checkoutCreatedAt'] ?? order['createdAt'];
      if (createdAt is Timestamp) placedOn = createdAt.toDate();
    } else {
      items = order['items'] as List<dynamic>? ?? [];
      total = (order['totalAmount'] ?? 0.0).toDouble();
      final createdAt = order['createdAt'];
      if (createdAt is Timestamp) placedOn = createdAt.toDate();
    }

    final timeStr = DateFormat('hh:mm a').format(placedOn);
    final isToday = DateFormat('yyyy-MM-dd').format(placedOn) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final displayTime = isToday ? 'Today, $timeStr' : '${DateFormat('MMM dd').format(placedOn)}, $timeStr';

    // Derive live aggregate status from per-item statuses (reflects staff actions in real-time)
    String uiStatus = status;

    if (items.isNotEmpty) {
      int readyCount = 0;
      int servedCount = 0;
      int skippedCount = 0;
      int totalCount = items.length;

      for (final item in items) {
        final isPreReady = item['isPreReady'] ?? item['isReadyMade'] ?? false;
        final rawStatus = (item['itemStatus'] as String? ?? 'pending').toLowerCase();
        
        // Effective status for this item
        final iStatus = isPreReady 
            ? (rawStatus == 'served' || rawStatus == 'skipped' || rawStatus == 'cancelled' ? rawStatus : 'ready') 
            : rawStatus;

        if (iStatus == 'served') {
          servedCount++;
        } else if (iStatus == 'ready') {
          readyCount++;
        } else if (iStatus == 'skipped' || iStatus == 'cancelled') {
          skippedCount++;
        }
      }

      // Determine session timing
      final now = DateTime.now();
      bool hasLiveSessionItem = false;
      bool hasOnlyFutureItems = true;

      for (final item in items) {
        final startTimeStr = item['selectedSlotStartTime'] as String?;
        if (startTimeStr != null) {
          try {
            final format = DateFormat('hh:mm a');
            final startTime = format.parse(startTimeStr);
            final sessionTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
            
            if (sessionTime.isBefore(now) || sessionTime.difference(now).inMinutes < 60) {
              hasLiveSessionItem = true;
              hasOnlyFutureItems = false;
            }
          } catch (_) {}
        } else {
          hasLiveSessionItem = true;
          hasOnlyFutureItems = false;
        }
      }

      if (servedCount == totalCount) {
        uiStatus = 'served';
      } else if (servedCount + readyCount == totalCount) {
        // If everything is served or ready, it's READY overall
        uiStatus = 'ready';
      } else if (servedCount > 0) {
        uiStatus = 'partial'; // Partially SERVED
      } else if (skippedCount == totalCount) {
        uiStatus = 'skipped';
      } else if (hasOnlyFutureItems && readyCount == 0) {
        uiStatus = 'scheduled';
      } else if (hasLiveSessionItem || readyCount > 0) {
        uiStatus = 'pending';
      } else {
        uiStatus = status;
      }
    }

    IconData getIcon() {
      final firstName = items.isNotEmpty ? (items.first['nameSnapshot'] ?? '').toLowerCase() : '';
      if (firstName.contains('burger')) return Icons.restaurant;
      if (firstName.contains('coffee') || firstName.contains('latte')) return Icons.local_cafe;
      if (firstName.contains('fries')) return Icons.fastfood;
      return Icons.restaurant;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(getIcon(), color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORDER #$token',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayTime,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildStatusChip(uiStatus),
            ],
          ),
          const SizedBox(height: 16),
          // Individual Items List
          ...items.map((item) {
            final bool isPreReady = item['isPreReady'] ?? item['isReadyMade'] ?? false;
            // If pre-ready use 'ready' as effective status, otherwise use live Firestore itemStatus
            final String rawStatus = (item['itemStatus'] as String? ?? 'pending').toLowerCase();
            final String itemStatus = isPreReady
                ? (rawStatus == 'served' || rawStatus == 'skipped' || rawStatus == 'cancelled' ? rawStatus : 'ready')
                : rawStatus;
            final String? slotStart = item['selectedSlotStartTime'];
            final String? slotEnd = item['selectedSlotEndTime'];
            final String slotDisplay = (slotStart != null && slotEnd != null) 
                ? '$slotStart - $slotEnd' 
                : 'Ready soon';
                
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['nameSnapshot']} x${item['quantity']}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Slot: $slotDisplay',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildItemStatusMiniPill(itemStatus),
                ],
              ),
            );
          }),
          if (uiStatus == 'skipped') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Skipped (not at counter). Please wait for next call.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEF4444),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Total Amount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showOrderDetailsModal(context, order),
                  child: Row(
                    children: [
                      Text(
                        'Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsModal(BuildContext context, Map<String, dynamic> order) {
    final List<dynamic> items;
    final double total;
    final String token = order['tokenNumber'] ?? 'XXXX';
    final String status = order['orderStatus'] as String? ?? 'pending';
    DateTime placedOn = DateTime.now();
    String sessionName = '';

    if (order['isAggregated'] == true) {
      final List<Map<String, dynamic>> subOrders = List<Map<String, dynamic>>.from(order['subOrders'] ?? []);
      items = subOrders.expand((o) => o['items'] as List<dynamic>? ?? []).toList();
      total = subOrders.fold(0.0, (acc, o) => acc + (o['totalAmount'] ?? 0.0));
      final createdAt = order['checkoutCreatedAt'] ?? order['createdAt'];
      if (createdAt is Timestamp) placedOn = createdAt.toDate();
      sessionName = subOrders.map((o) => o['sessionNameSnapshot'] ?? '').toSet().join(', ');
    } else {
      items = order['items'] as List<dynamic>? ?? [];
      total = (order['totalAmount'] ?? 0.0).toDouble();
      final createdAt = order['createdAt'];
      if (createdAt is Timestamp) placedOn = createdAt.toDate();
      sessionName = order['sessionNameSnapshot'] ?? 'Daily Menu';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Details', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800)),
                      Text('Token #$token', style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  _buildStatusChip(status, isLight: true),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildDetailRow('Placed On', DateFormat('MMM dd, yyyy • hh:mm a').format(placedOn)),
                  _buildDetailRow('Session', sessionName),
                  const SizedBox(height: 24),
                  Text('ITEMS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  ... (order['isAggregated'] == true 
                      ? (order['subOrders'] as List).expand((sub) {
                          final subItems = sub['items'] as List? ?? [];
                          final slotInfo = (sub['slotStartTime'] != null) 
                              ? '${sub['slotStartTime']} - ${sub['slotEndTime']}'
                              : null;
                          return subItems.map((item) => {
                            ...Map<String, dynamic>.from(item),
                            'slotDisplay': slotInfo,
                          });
                        }).toList()
                      : items.map((item) => {
                          ...Map<String, dynamic>.from(item),
                          'slotDisplay': (order['slotStartTime'] != null)
                              ? '${order['slotStartTime']} - ${order['slotEndTime']}'
                              : null,
                        }).toList()
                  ).map((item) {
                    final bool isPreReady = item['isPreReady'] ?? item['isReadyMade'] ?? false;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              image: item['imageSnapshot'] != null ? DecorationImage(image: NetworkImage(item['imageSnapshot']), fit: BoxFit.cover) : null,
                            ),
                            child: item['imageSnapshot'] == null ? const Icon(Icons.fastfood, color: Colors.grey) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['nameSnapshot'] ?? 'Item', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Qty: ${item['quantity'] ?? 1}', style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 12),
                                    Text('₹${((item['priceSnapshot'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (isPreReady)
                                  _buildStatusChip('READY', isLight: true)
                                else if (item['slotDisplay'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.access_time_filled, size: 12, color: Color(0xFF6B7280)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Pickup: ${item['slotDisplay']}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF4B5563),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  Text('TRANSACTION DETAILS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  _buildDetailRow('Transaction ID', 'TXN${token}987654321'),
                  _buildDetailRow('Payment Method', 'Online Payment (Mock)'),
                  _buildDetailRow('Status', 'Success'),
                  _buildDetailRow('Tax & Fees', '₹0'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -10))]),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('₹${total.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isActiveOrderSlot(Map<String, dynamic> order) {
    if (order['isAggregated'] == true) {
      final sub = List<Map<String, dynamic>>.from(order['subOrders'] ?? []);
      return sub.isNotEmpty && sub.first['slotStartTime'] != null;
    }
    return order['slotStartTime'] != null;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildItemStatusMiniPill(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'ready':
        color = StudentTheme.statusAmber;
        break;
      case 'served':
        color = StudentTheme.statusGreen;
        break;
      case 'preparing':
        color = StudentTheme.accent;
        break;
      default:
        color = Colors.white.withValues(alpha: 0.3);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, {bool isLight = false}) {
    Color bg;
    Color text;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'served':
        bg = StudentTheme.statusGreen;
        text = Colors.white;
        break;
      case 'ready':
        bg = const Color(0xFFF9AB00);
        text = Colors.white;
        break;
      case 'preparing':
        bg = Colors.orange;
        text = Colors.white;
        break;
      case 'scheduled':
        bg = Colors.blue.shade400;
        text = Colors.white;
        break;
      case 'partial':
        bg = const Color(0xFF8B5CF6); // Purple for partial
        text = Colors.white;
        break;
      case 'confirmed':
        bg = Colors.blue.shade600; // Deep blue for confirmed
        text = Colors.white;
        break;
      case 'partial served':
        bg = const Color(0xFFB06000);
        text = Colors.white;
        break;
      case 'skipped':
      case 'cancelled':
        bg = StudentTheme.statusRed;
        text = Colors.white;
        break;
      default:
        bg = StudentTheme.textSecondary;
        text = Colors.white;
    }

    if (isLight) {
      // For white background (modal)
      bg = bg.withValues(alpha: 0.15);
      text = bg.withValues(alpha: 1.0).withAlpha(255); // Solid version of the same color
      // Better: use the original solid color for text if it's readable on light bg, 
      // but the admin theme uses a lighter bg and the same text color.
      // Let's find a more robust way to get the text color for light theme.
      switch (status.toLowerCase()) {
        case 'served': text = const Color(0xFF065F46); break;
        case 'ready': text = const Color(0xFFB06000); break; // Darker gold
        case 'preparing': text = const Color(0xFF9A3412); break; // Darker orange
        case 'scheduled': text = Colors.blue.shade800; break;
        case 'partial': text = const Color(0xFF5B21B6); break; // Darker purple
        case 'confirmed': text = const Color(0xFF1E3A8A); break; // Darker blue
        case 'partial served': text = const Color(0xFF78350F); break;
        case 'skipped':
        case 'cancelled': text = const Color(0xFF991B1B); break;
        default: text = const Color(0xFF374151);
      }
    } else {
      bg = bg.withValues(alpha: 0.2);
      text = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
