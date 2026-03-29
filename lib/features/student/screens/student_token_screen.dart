import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/themes/student_theme.dart';
import '../../../core/providers.dart';
import '../providers/student_orders_provider.dart';
import '../widgets/student_active_token_card.dart';
import '../services/student_notification_service.dart';

class StudentTokenScreen extends ConsumerStatefulWidget {
  const StudentTokenScreen({super.key});

  @override
  ConsumerState<StudentTokenScreen> createState() => _StudentTokenScreenState();
}

class _StudentTokenScreenState extends ConsumerState<StudentTokenScreen> {
  late final PageController _pageCtrl;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);
    _pageCtrl.addListener(() {
      final p = _pageCtrl.page?.round() ?? 0;
      if (p != _currentPage) setState(() => _currentPage = p);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = ref.watch(studentActiveOrdersProvider);
    final pastOrders = ref.watch(studentOrderHistoryProvider);

    return Scaffold(
      backgroundColor: StudentTheme.background,
      appBar: _buildAppBar(context, ref, pastOrders),
      body: activeOrders.isEmpty
          ? _buildEmptyState()
          : _buildContent(activeOrders),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> pastOrders,
  ) {
    final profile = ref.watch(userProfileProvider).value;
    final firstName = profile?.displayName.split(' ').first ?? 'Student';
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return AppBar(
      backgroundColor: StudentTheme.background,
      elevation: 0,
      toolbarHeight: 90,
      leadingWidth: 72,
      leading: Center(
        child: Container(
          margin: const EdgeInsets.only(left: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: StudentTheme.primary,
              size: 18,
            ),
            onPressed: () => context.go('/student/dashboard'),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: StudentTheme.primary.withValues(alpha: 0.1),
                width: 2,
              ),
              image: DecorationImage(
                image: (profile?.imageUrl?.isNotEmpty ?? false)
                    ? NetworkImage(profile!.imageUrl!)
                    : const NetworkImage(
                            'https://lh3.googleusercontent.com/a/ACg8ocL_V_j_X_V_j_X_V_j_X_V_j_X_V_j_X_V=s96-c',
                          )
                          as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello, $firstName',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: StudentTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'My Tokens',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: StudentTheme.primary,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.history_rounded,
              color: StudentTheme.primary,
              size: 22,
            ),
            onPressed: () => _showPastTokensModal(pastOrders),
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: StudentTheme.primary,
                  size: 22,
                ),
                onPressed: () => context.push('/student/notifications'),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: 10,
                right: 14,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: StudentTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> activeOrders) {
    return Column(
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: StudentTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Active Tokens',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: StudentTheme.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: StudentTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${activeOrders.length}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: StudentTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Card carousel
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: activeOrders.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final isActive = index == _currentPage;
              return AnimatedScale(
                scale: isActive ? 1.0 : 0.96,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: EdgeInsets.only(
                    left: index == 0 ? 4 : 6,
                    right: index == activeOrders.length - 1 ? 20 : 6,
                    bottom: isActive ? 4 : 12,
                    top: isActive ? 4 : 10,
                  ),
                  child: StudentActiveTokenCard(
                    order: activeOrders[index],
                    tokenIndex: index + 1,
                    isActive: isActive,
                  ),
                ),
              );
            },
          ),
        ),

        // Dots
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(activeOrders.length, (i) {
              final isOn = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isOn ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isOn
                      ? StudentTheme.primary
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: Text(
            'swipe to see more tokens',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: Colors.black26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: StudentTheme.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.confirmation_num_rounded,
              size: 36,
              color: StudentTheme.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No active tokens',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: StudentTheme.primary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Your active tokens will appear here once you place an order.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: StudentTheme.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPastTokensModal(List<Map<String, dynamic>> pastOrders) {
    Set<String> selectedGroups = {};
    bool isSelectionMode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final hasSelection = selectedGroups.isNotEmpty;

          Future<void> handleDelete() async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(
                  'Delete Tokens?',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: Text(
                  'Selected tokens will be hidden from your history.',
                  style: GoogleFonts.plusJakartaSans(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await ref
                  .read(studentOrderServiceProvider)
                  .hideCheckoutGroups(selectedGroups.toList());
              setModalState(() {
                isSelectionMode = false;
                selectedGroups.clear();
              });
              // The stream provider will automatically update the list
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Row(
                    children: [
                      Text(
                        isSelectionMode
                            ? '${selectedGroups.length} Selected'
                            : 'Past Tokens',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const Spacer(),
                      if (isSelectionMode && hasSelection)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                          onPressed: handleDelete,
                        ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            isSelectionMode = !isSelectionMode;
                            if (!isSelectionMode) selectedGroups.clear();
                          });
                        },
                        child: Text(
                          isSelectionMode ? 'Cancel' : 'Select',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: isSelectionMode
                                ? Colors.grey
                                : StudentTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: pastOrders.isEmpty
                      ? Center(
                          child: Text(
                            'No past tokens found',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey.shade400,
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: pastOrders.length,
                          itemBuilder: (_, i) {
                            final order = pastOrders[i];
                            final groupId =
                                order['checkoutGroupId'] ?? order['orderId'];
                            final isSelected = selectedGroups.contains(groupId);

                            return _PastTokenCard(
                              order: order,
                              isSelectionMode: isSelectionMode,
                              isSelected: isSelected,
                              onTap: () {
                                if (isSelectionMode) {
                                  setModalState(() {
                                    if (isSelected) {
                                      selectedGroups.remove(groupId);
                                    } else {
                                      selectedGroups.add(groupId);
                                    }
                                  });
                                }
                              },
                              onLongPress: () {
                                if (!isSelectionMode) {
                                  setModalState(() {
                                    isSelectionMode = true;
                                    selectedGroups.add(groupId);
                                  });
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PastTokenCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PastTokenCard({
    required this.order,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final token = order['tokenNumber'] ?? '—';
    final List<dynamic> tItems = order['items'] ?? [];
    int servedCount = 0;
    int readyCount = 0;
    int totalCount = tItems.length;

    for (final item in tItems) {
      final isPreReady = item['isPreReady'] ?? item['isReadyMade'] ?? false;
      final rawSubStatus = (item['itemStatus'] as String? ?? 'pending')
          .toLowerCase();
      final iStatus = isPreReady
          ? (rawSubStatus == 'served' ||
                    rawSubStatus == 'skipped' ||
                    rawSubStatus == 'cancelled'
                ? rawSubStatus
                : 'ready')
          : rawSubStatus;

      if (iStatus == 'served')
        servedCount++;
      else if (iStatus == 'ready')
        readyCount++;
    }

    String derivedStatus = 'pending';
    if (totalCount > 0) {
      if (servedCount == totalCount)
        derivedStatus = 'served';
      else if (servedCount + readyCount == totalCount)
        derivedStatus = 'ready';
      else if (servedCount > 0)
        derivedStatus = 'partial';
    } else {
      // fallback if no items list
      final statusCategory = order['statusCategory'] as String? ?? '';
      final rawStatus = order['orderStatus'] as String? ?? '';
      derivedStatus = (statusCategory.isNotEmpty ? statusCategory : rawStatus)
          .toLowerCase();
    }

    // Status text label logic matched with current app
    String status = derivedStatus.isEmpty ? 'served' : derivedStatus;

    final total = (order['totalAmount'] ?? 0.0) as double;

    final date = order['checkoutCreatedAt'] != null
        ? (order['checkoutCreatedAt'] as Timestamp).toDate()
        : order['createdAt'] != null
        ? (order['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    Color statusColor;
    switch (status) {
      case 'cancelled':
      case 'skipped':
        statusColor = const Color(0xFFEF4444);
        break;
      case 'partial':
        statusColor = const Color(0xFFF59E0B);
        break;
      default:
        statusColor = const Color(0xFF10B981);
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? StudentTheme.primary
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? StudentTheme.primary : Colors.white24,
                  size: 22,
                ),
              ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Token #$token',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMM dd · hh:mm a').format(date),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
