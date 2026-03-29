import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/themes/student_theme.dart';
import 'student_qr_sheet.dart';

const _red = Color(0xFFD9372A);
const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _blue = Color(0xFF93C5FD);

const _gradients = [
  [Color(0xFFD9372A), Color(0xFFF59E0B), Color(0xFFF4A8C4)],
  [Color(0xFF1E3A5F), Color(0xFF7C3AED), Color(0xFFC4B8F0)],
  [Color(0xFF064E3B), Color(0xFF0F766E), Color(0xFF93C5FD)],
  [Color(0xFF831843), Color(0xFFBE185D), Color(0xFFF4A8C4)],
  [Color(0xFF1E1B4B), Color(0xFF3730A3), Color(0xFF93C5FD)],
];

class StudentActiveTokenCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final int tokenIndex;
  final bool isActive;

  const StudentActiveTokenCard({
    super.key,
    required this.order,
    required this.tokenIndex,
    this.isActive = true,
  });

  @override
  State<StudentActiveTokenCard> createState() => _StudentActiveTokenCardState();
}

class _StudentActiveTokenCardState extends State<StudentActiveTokenCard> {
  @override
  void didUpdateWidget(StudentActiveTokenCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasCalled = oldWidget.order['isCalledForPickup'] as bool? ?? false;
    final isCalled = widget.order['isCalledForPickup'] as bool? ?? false;
    final lastCalledOld = oldWidget.order['lastCalledAt'];
    final lastCalledNew = widget.order['lastCalledAt'];

    final becameCalled = !wasCalled && isCalled;
    final wasReCalled =
        isCalled && lastCalledNew != null && lastCalledNew != lastCalledOld;

    final oldStatus = (oldWidget.order['orderStatus'] as String? ?? '')
        .toLowerCase();
    final newStatus = (widget.order['orderStatus'] as String? ?? '')
        .toLowerCase();

    if (becameCalled || wasReCalled) {
      _triggerPickupAlert();
    } else if (oldStatus != 'served' && newStatus == 'served') {
      _triggerServedAlert();
    }
  }

  void _triggerPickupAlert() {
    HapticFeedback.vibrate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Token #${widget.order['tokenNumber']} is ready for pickup!',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            backgroundColor: StudentTheme.primaryOrange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  void _triggerServedAlert() {
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Token #${widget.order['tokenNumber']} has been served. Enjoy!',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            backgroundColor: StudentTheme.statusGreenText,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isCalledForPickup =
        widget.order['isCalledForPickup'] as bool? ?? false;
    final orderId =
        (widget.order['orderId'] ?? widget.order['checkoutGroupId'] ?? '')
            .toString();
    final shortId = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();

    // Aggregation logic
    final List<Map<String, dynamic>> items;
    final double totalAmount;

    if (widget.order['isAggregated'] == true) {
      final List<Map<String, dynamic>> subOrders =
          List<Map<String, dynamic>>.from(widget.order['subOrders'] ?? []);
      items = subOrders
          .expand(
            (o) => List<Map<String, dynamic>>.from(
              o['items'] as List<dynamic>? ?? [],
            ),
          )
          .toList();
      totalAmount = subOrders.fold(
        0.0,
        (totalValue, o) =>
            totalValue + ((o['totalAmount'] ?? 0.0) as num).toDouble(),
      );
    } else {
      items = List<Map<String, dynamic>>.from(
        widget.order['items'] as List<dynamic>? ?? [],
      );
      totalAmount = ((widget.order['totalAmount'] ?? 0.0) as num).toDouble();
    }

    // Derive live status
    int servedCount = 0;
    int readyCount = 0;
    int totalCount = items.length;

    for (final item in items) {
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

    String derivedStatus = (widget.order['orderStatus'] as String? ?? 'pending')
        .toLowerCase();

    // Perform detailed refinement if it's a generic status
    if (totalCount > 0) {
      if (servedCount == totalCount) {
        derivedStatus = 'served';
      } else if (servedCount + readyCount == totalCount) {
        // If everything is either served or ready, it's READY for the student
        derivedStatus = 'ready';
      } else if (servedCount > 0) {
        // Some items served, some not yet ready -> PARTIAL
        derivedStatus = 'partial';
      } else if (items.any(
        (it) => (it['itemStatus'] as String? ?? '').toLowerCase() == 'skipped',
      )) {
        // If any item was skipped and nothing is served yet -> SKIPPED
        derivedStatus = 'skipped';
      }
    }

    Color statusColor;
    String statusLabel;

    if (isCalledForPickup &&
        (derivedStatus == 'ready' || derivedStatus == 'partial')) {
      statusColor = _red;
      statusLabel = 'CALLED';
    } else {
      switch (derivedStatus) {
        case 'ready':
        case 'served':
          statusColor = _green;
          statusLabel = derivedStatus.toUpperCase();
          break;
        case 'partial':
        case 'partial served':
          statusColor = _amber;
          statusLabel = derivedStatus.toUpperCase();
          break;
        case 'skipped':
          statusColor = _amber;
          statusLabel = 'SKIPPED';
          break;
        case 'pending':
        case 'scheduled':
          statusColor = _blue;
          statusLabel = derivedStatus == 'scheduled' ? 'SCHEDULED' : 'PENDING';
          break;
        default:
          statusColor = _green;
          statusLabel = derivedStatus.toUpperCase();
      }
    }

    final Map<String, List<Map<String, dynamic>>> groups = {};
    final Map<String, String> sessNames = {};
    final Map<String, String> sessSlots = {};

    for (final item in items) {
      final sId = (item['sessionId'] as String?) ?? 'default';
      final sName = (item['sessionNameSnapshot'] as String?) ?? 'Session';
      final slotOptions = [
        item['selectedSlotStartTime'],
        item['slotStartTime'],
      ];
      final slotStr =
          slotOptions.firstWhere(
                (e) => e != null && e.toString().isNotEmpty,
                orElse: () => '',
              )
              as String;

      String slot = '';
      if (slotStr.isNotEmpty) {
        slot = '$slotStr slot';
      }

      groups.putIfAbsent(sId, () => []).add(item);
      sessNames[sId] = sName;
      if (slot.isNotEmpty) sessSlots[sId] = slot;
    }

    final gradColors = _gradients[widget.tokenIndex % _gradients.length];
    final sessionSummary = sessNames.values
        .map((s) => s.toUpperCase())
        .join(' + ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: widget.isActive ? 0.13 : 0.06,
            ),
            blurRadius: widget.isActive ? 32 : 14,
            offset: Offset(0, widget.isActive ? 10 : 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () => _showBigTokenDialog(
            context,
            widget.order['tokenNumber']?.toString() ??
                widget.tokenIndex.toString(),
          ),
          splashColor: Colors.black.withValues(alpha: 0.05),
          highlightColor: Colors.black.withValues(alpha: 0.02),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -25,
                      right: -25,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -35,
                      left: 20,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.09),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 18,
                      child: Text(
                        '#${widget.order['tokenNumber'] ?? widget.tokenIndex}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 62,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: -4,
                          height: 1,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sessionSummary,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Order #$shortId',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ORDER ITEMS BY SESSION',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade300,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...groups.entries.map((entry) {
                          final sId = entry.key;
                          final sItems = entry.value;
                          final sName = sessNames[sId] ?? 'Session';
                          final sSlot = sessSlots[sId] ?? '';
                          return _SessionGroup(
                            sessionName: sName,
                            slot: sSlot,
                            items: sItems,
                            statusColor: statusColor,
                          );
                        }),
                        Container(
                          margin: const EdgeInsets.only(top: 2, bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF0F0F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StatItem(
                                'ITEMS',
                                '${items.length}',
                                Colors.black87,
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: const Color(0xFFEFEFEF),
                              ),
                              _StatItem(
                                'SESSIONS',
                                '${groups.length}',
                                Colors.black87,
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: const Color(0xFFEFEFEF),
                              ),
                              _StatItem(
                                'TOTAL',
                                '₹${totalAmount.toStringAsFixed(0)}',
                                statusColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  onTap: () {
                    final groupId = widget.order['checkoutGroupId'] ?? '';
                    final tkn = widget.order['tokenNumber']?.toString() ?? '';
                    if (groupId.isNotEmpty && tkn.isNotEmpty) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => StudentQrSheet(
                          checkoutGroupId: groupId,
                          tokenNumber: tkn,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: gradColors[0],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'View QR Details',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBigTokenDialog(BuildContext context, String token) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
                ),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.82,
                  height: MediaQuery.of(context).size.width * 0.82, // Square
                  decoration: BoxDecoration(
                    color: StudentTheme.primary,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Large decorative circle
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'TOKEN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white38,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '#$token',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 140,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -8,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 30,
                        child: Text(
                          'Tap anywhere to dismiss',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionGroup extends StatelessWidget {
  final String sessionName, slot;
  final List<Map<String, dynamic>> items;
  final Color statusColor;

  const _SessionGroup({
    required this.sessionName,
    required this.slot,
    required this.items,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 11,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 5),
              Text(
                sessionName.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9CA3AF),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (slot.isNotEmpty)
                Text(
                  slot,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map((item) {
            final iStatus = (item['itemStatus'] ?? 'pending')
                .toString()
                .toLowerCase();
            Color iColor;
            switch (iStatus) {
              case 'ready':
              case 'served':
                iColor = _green;
                break;
              case 'skipped':
              case 'partial':
              case 'preparing':
              case 'accepted':
                iColor = _amber;
                break;
              default:
                iColor = _blue;
            }
            final qty = (item['quantity'] ?? 1) as int;
            final name = (item['nameSnapshot'] ?? 'Item') as String;
            return Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '×$qty',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: iColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      iStatus.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: iColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatItem(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 1),
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade300,
          letterSpacing: 0.3,
        ),
      ),
    ],
  );
}
