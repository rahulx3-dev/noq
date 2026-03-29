import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/order_classification_helper.dart';
import '../../../core/providers.dart';
import '../../../app/themes/admin_theme.dart';
import '../widgets/admin_breadcrumbs.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  DocumentSnapshot<Map<String, dynamic>>? _selectedOrder;
  String _searchQuery = '';
  String _selectedSession = 'ALL SESSIONS';
  String _selectedStatus = 'ALL';
  String _dateFilterLabel = 'TODAY';
  DateTime _dateStart = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  late final TextEditingController _searchController;
  Timer? _searchTimer;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _ordersStream;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _updateOrdersStream();
  }

  void _updateOrdersStream() {
    _ordersStream = ref
        .read(firestoreServiceProvider)
        .getOrdersByOrderDate(
          'default',
          DateFormat('yyyy-MM-dd').format(_dateStart),
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  final List<String> _statusTabs = [
    'ALL',
    'SCHEDULED',
    'PENDING',
    'PREPARING',
    'READY',
    'SERVED',
    'PARTIAL SERVED',
    'SKIPPED',
    'CANCELLED',
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final err = snapshot.error.toString().toLowerCase();
            if (err.contains('network') || err.contains('unavailable')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/admin/no-network');
              });
            }
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AdminTheme.primary),
            );
          }

          final rawDocs = snapshot.data!.docs;

          // 1. Aggregation by checkoutGroupId
          final Map<String, List<DocumentSnapshot<Map<String, dynamic>>>>
          groups = {};
          for (final doc in rawDocs) {
            final data = doc.data();
            final groupId = data['checkoutGroupId'] ?? doc.id;
            groups.putIfAbsent(groupId, () => []).add(doc);
          }

          // 2. Map groups to Aggregate objects and Filter
          final List<Map<String, dynamic>> filteredGroups = [];

          groups.forEach((groupId, docs) {
            final firstData = docs.first.data()!;
            final List<Map<String, dynamic>> groupOrders = docs.map((d) {
              final dMap = Map<String, dynamic>.from(d.data()!);
              dMap['orderId'] = d.id;
              return dMap;
            }).toList();

            // Client-side sort within group if necessary (though usually they are same slot)
            groupOrders.sort((a, b) {
              final aTime = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTime = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });

            // Calculate aggregate status
            final aggregateStatus =
                OrderClassificationHelper.getAggregateStatus(
                  groupOrders,
                ).toUpperCase();

            // Search filter
            final search = _searchQuery.toLowerCase();
            final orderId = docs.first.id.toLowerCase();
            final token =
                (firstData['tokenNumber'] ??
                        groupId.substring(
                          groupId.length > 4 ? groupId.length - 4 : 0,
                        ))
                    .toString()
                    .toLowerCase();
            final studentName = (firstData['studentName'] ?? '')
                .toString()
                .toLowerCase();

            final matchesSearch =
                search.isEmpty ||
                token.contains(search) ||
                studentName.contains(search) ||
                orderId.contains(search);

            // Status filter
            final matchesStatus =
                _selectedStatus == 'ALL' || aggregateStatus == _selectedStatus;

            // Session filter
            final sessionSnapshot = (firstData['sessionNameSnapshot'] ?? firstData['sessionName'] ?? '')
                .toString()
                .toUpperCase();
            final matchesSession =
                _selectedSession == 'ALL SESSIONS' ||
                sessionSnapshot == _selectedSession;

            if (matchesSearch &&
                matchesStatus &&
                matchesSession) {
              filteredGroups.add({
                'groupId': groupId,
                'docs': docs,
                'aggregateStatus': aggregateStatus,
                'token': token,
                'studentName': studentName,
                'sessionName': firstData['sessionNameSnapshot'] ?? firstData['sessionName'] ?? 'Lunch',
                'createdAt':
                    (firstData['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              });
            }
          });

          // Sort by time descending
          filteredGroups.sort(
            (a, b) => (b['createdAt'] as DateTime).compareTo(
              a['createdAt'] as DateTime,
            ),
          );

          // 3. Auto-select/Validate selection for Desktop
          if (isDesktop) {
            final isStillVisible = filteredGroups.any((g) =>
                (g['docs'] as List<DocumentSnapshot<Map<String, dynamic>>>)
                    .any((d) => d.id == _selectedOrder?.id));

            if (!isStillVisible || _selectedOrder == null) {
              if (filteredGroups.isNotEmpty) {
                _selectedOrder = filteredGroups.first['docs'].first;
              } else {
                _selectedOrder = null;
              }
            }
          }

          // 4. Calculate summary counts
          int pendingCount = 0;
          int readyCount = 0;
          for (var g in filteredGroups) {
            final st = g['aggregateStatus'] as String;
            if (st == 'PENDING') pendingCount++;
            if (st == 'READY') readyCount++;
          }

          return isDesktop
              ? _buildDesktopLayout(filteredGroups, pendingCount, readyCount)
              : _buildMobileLayout(filteredGroups, pendingCount, readyCount);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = _dateStart.isAfter(today);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isFuture ? Icons.event_available_outlined : Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isFuture ? 'No upcoming orders for this date' : 'No orders found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AdminTheme.textSecondary,
            ),
          ),
          if (isFuture) ...[
            const SizedBox(height: 8),
            Text(
              'Pre-orders have not been placed yet.',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AdminTheme.textSecondary),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(List<Map<String, dynamic>> groupAggregates, int pendingCount, int readyCount) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminBreadcrumbs(
                      items: [
                        AdminBreadcrumbItem(label: 'Home', route: '/admin'),
                        AdminBreadcrumbItem(label: 'Orders'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Orders',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '${groupAggregates.length} orders · $_dateFilterLabel',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _countBadge('$pendingCount Pending', const Color(0xFFFEF2F2), const Color(0xFF991B1B)),
                            const SizedBox(width: 8),
                            _countBadge('$readyCount Ready', const Color(0xFFF0FDF4), const Color(0xFF166534)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: _buildFilters(context),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: groupAggregates.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        itemCount: groupAggregates.length,
                        itemBuilder: (context, index) {
                          final aggregate = groupAggregates[index];
                          // Identify if any doc in the group is selected
                          final docs =
                              aggregate['docs']
                                  as List<
                                    DocumentSnapshot<Map<String, dynamic>>
                                  >;
                          final isSelected = docs.any(
                            (d) => d.id == _selectedOrder?.id,
                          );
                          return _buildOrderCard(aggregate, isSelected);
                        },
                      ),
              ),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: AdminTheme.border),
        Expanded(
          flex: 4,
          child: _selectedOrder == null
              ? const Center(child: Text('Select an order to view details'))
              : _buildOrderDetailsPanel(_selectedOrder!),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<Map<String, dynamic>> groupAggregates, int pendingCount, int readyCount) {
    return Column(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orders',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '${groupAggregates.length} items · $_dateFilterLabel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    _buildDateFilter(),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _countBadge('$pendingCount Pending', const Color(0xFFFEF2F2), const Color(0xFF991B1B)),
                    const SizedBox(width: 6),
                    _countBadge('$readyCount Ready', const Color(0xFFF0FDF4), const Color(0xFF166534)),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildSessionChips(),
              const SizedBox(height: 12),
              _buildStatusTabs(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: groupAggregates.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groupAggregates.length,
                  itemBuilder: (context, index) {
                    final aggregate = groupAggregates[index];
                    return _buildOrderCard(aggregate, false, isMobile: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSearchBar()),
            const SizedBox(width: 16),
            _buildDateFilter(),
          ],
        ),
        const SizedBox(height: 24),
        _buildSessionChips(),
        const SizedBox(height: 16),
        _buildStatusTabs(),
      ],
    );
  }

  Widget _countBadge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _dateStart,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Colors.black,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            final now = DateTime.now();
            final isToday = picked.year == now.year &&
                picked.month == now.month &&
                picked.day == now.day;
            _dateFilterLabel = isToday ? 'TODAY' : DateFormat('dd MMM yyyy').format(picked);
            _dateStart = DateTime(picked.year, picked.month, picked.day);
            _selectedOrder = null;
            _updateOrdersStream();
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminTheme.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: AdminTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              _dateFilterLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: AdminTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionChips() {
    final sessionsAsync = ref.watch(sessionsStreamProvider);

    return sessionsAsync.when(
      data: (sessions) {
        final activeSessions = sessions.where((s) => s.isActive).toList();
        final sessionNames = [
          'ALL SESSIONS',
          ...activeSessions.map((s) => s.name.toUpperCase()),
        ];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: sessionNames.map((s) {
              final isSelected = _selectedSession == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s),
                  selected: isSelected,
                  onSelected: (v) => setState(() => _selectedSession = s),
                  selectedColor: Colors.black,
                  showCheckmark: false,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.black : Colors.grey[300]!,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 32,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (e, s) => Text('Error: $e'),
    );
  }



  Widget _buildStatusTabs() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusTabs.map((s) {
          final isSelected = _selectedStatus == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedStatus = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Map<String, Color> _getStatusColors(String status) {
    switch (status.toLowerCase()) {
      case 'served':
        return {
          'bg': const Color(0xFFD1FAE5),
          'fg': const Color(0xFF065F46),
        };
      case 'ready':
        return {
          'bg': const Color(0xFFFEFCE8),
          'fg': const Color(0xFFA16207),
        };
      case 'partial':
      case 'partial served':
        return {
          'bg': const Color(0xFFFEF3C7),
          'fg': const Color(0xFFB45309),
        };
      case 'preparing':
        return {
          'bg': const Color(0xFFFFF7ED),
          'fg': const Color(0xFFC2410C),
        };
      case 'skipped':
        return {
          'bg': const Color(0xFFFFF7ED),
          'fg': const Color(0xFFB45309),
        };
      case 'cancelled':
        return {
          'bg': const Color(0xFFFEF2F2),
          'fg': const Color(0xFF991B1B),
        };
      case 'scheduled':
        return {
          'bg': const Color(0xFFEFF6FF),
          'fg': const Color(0xFF1D4ED8),
        };
      default:
        return {
          'bg': const Color(0xFFF3F4F6),
          'fg': const Color(0xFF6B7280),
        };
    }
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (v) {
        _searchTimer?.cancel();
        _searchTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _searchQuery = v);
          }
        });
      },
      controller: _searchController,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search token, name...',
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
          color: AdminTheme.textSecondary,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                }),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black26),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> aggregate,
    bool isSelected, {
    bool isMobile = false,
  }) {
    final status = aggregate['aggregateStatus'] as String;
    final createdAt = aggregate['createdAt'] as DateTime;
    final token = aggregate['token'].toString().toUpperCase();
    final studentName = aggregate['studentName'] ?? 'Student';
    final docs =
        aggregate['docs'] as List<DocumentSnapshot<Map<String, dynamic>>>;
    final firstDoc = docs.first;

    final colors = _getStatusColors(status);
    final statusBg = colors['bg']!;
    final statusFg = colors['fg']!;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedOrder = firstDoc);
        if (isMobile) _showMobileDetails(firstDoc);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : AdminTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusFg.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  token,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: statusFg,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${aggregate['sessionName'] ?? 'Lunch'} Session · ${DateFormat('hh:mm a').format(createdAt)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: statusFg,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileDetails(DocumentSnapshot<Map<String, dynamic>> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _buildOrderDetailsPanel(doc),
      ),
    );
  }

  Widget _buildOrderDetailsPanel(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final items = data['items'] as List? ?? [];
    final status = (data['orderStatus'] ?? 'pending').toString().toUpperCase();
    final token =
        (data['tokenNumber']?.toString() ??
                doc.id.substring(doc.id.length > 4 ? doc.id.length - 4 : 0))
            .toUpperCase();
    final studentName = data['studentName'] ?? 'Student';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColors(status)['bg']!.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'TOKEN #$token',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: _getStatusColors(status)['fg']!,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSessionBadge(data['sessionNameSnapshot'] ?? data['sessionName'] ?? 'Lunch'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          studentName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, hh:mm a').format(
                                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusPill(status),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSectionHeader('ORDER ITEMS'),
              const SizedBox(height: 16),
              ...items.asMap().entries.map((entry) {
                return _buildItemRow(entry.value, entry.key, doc.id);
              }),
              const SizedBox(height: 32),
              _buildSectionHeader('PAYMENT INFO'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Payment Method',
                      (data['paymentMode'] ?? 'UPI').toString().toUpperCase(),
                      isHighlight: true,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1),
                    ),
                    _buildDetailRow(
                      'Payment Status',
                      (data['paymentStatus'] ?? 'PAID').toString().toUpperCase(),
                      textColor: (data['paymentStatus']?.toString().toUpperCase() == 'PAID') 
                          ? const Color(0xFF166534) 
                          : const Color(0xFF991B1B),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1),
                    ),
                    _buildDetailRow(
                      'Transaction ID',
                      (data['transactionId'] ?? 'N/A').toString(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '₹${data['totalAmount']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.black,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
              color: textColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item, int index, String orderId) {
    final itemStatus = (item['itemStatus'] ?? 'pending').toString().toLowerCase();
    final isPreReady = item['isPreReady'] ?? item['isReadyMade'] ?? false;
    final effectiveStatus = isPreReady ? 'ready' : itemStatus;

    final colors = _getStatusColors(effectiveStatus);
    final statusBg = colors['bg']!;
    final statusFg = colors['fg']!;

    final price = (item['priceSnapshot'] ?? item['price'] ?? 0) as num;
    final qty = (item['quantity'] ?? 1) as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'x$qty',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nameSnapshot'] ?? item['name'] ?? 'Item Name',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  (item['categorySnapshot'] ?? item['category'] ?? 'General').toString().toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${price * qty}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              // Live item status from Firestore
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  (isPreReady ? 'pre-ready' : effectiveStatus).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionBadge(String session) {
    Color color = Colors.blue;
    final s = session.toUpperCase();
    if (s.contains('MORNING')) color = Colors.orange;
    else if (s.contains('LUNCH')) color = Colors.amber;
    else if (s.contains('EVENING')) color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        s,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final colors = _getStatusColors(status);
    final bg = colors['bg']!;
    final fg = colors['fg']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
