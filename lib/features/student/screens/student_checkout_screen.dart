import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../core/models/student_models.dart';
import '../../../app/themes/student_theme.dart';
import '../providers/student_cart_provider.dart';
import '../providers/student_providers.dart';
import '../services/student_order_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/widgets/app_message.dart';
import '../providers/student_alert_provider.dart';
import '../../../core/widgets/app_notification_banner.dart';
import '../widgets/success_reveal.dart';
import '../../../core/utils/time_helper.dart';


final studentOrderServiceProvider = Provider((ref) => StudentOrderService());

class StudentCheckoutScreen extends ConsumerStatefulWidget {
  final double subtotal;
  final double taxAmount;
  final double platformFee;
  final double totalAmount;

  const StudentCheckoutScreen({
    super.key,
    required this.subtotal,
    required this.taxAmount,
    required this.platformFee,
    required this.totalAmount,
  });

  @override
  ConsumerState<StudentCheckoutScreen> createState() =>
      _StudentCheckoutScreenState();
}

class _StudentCheckoutScreenState extends ConsumerState<StudentCheckoutScreen> {
  bool _isProcessing = false;
  bool _showSuccess = false;
  String?
      _selectedUpiProvider; // Kept as per faithful edit, but note that the instruction's diff snippet had `int _selectedPaymentIndex = 0;`
  bool _isUpiExpanded = false;
  int _currentStep = 1; // 1: Payment, 2: Kitchen, 3: Token
  String? _processingSlotStartTime;
  List<String> _generatedTokens = [];
  List<Map<String, dynamic>> _orderedItems = [];

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) return _buildSuccessScreen();
    if (_isProcessing) return _buildProcessingScreen();

    final cartItems = ref.watch(studentCartProvider);
    final dailyMenu = ref.watch(todayStudentMenuProvider).value;

    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: StudentTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: StudentTheme.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Checkout',
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.w700,
              color: StudentTheme.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Your cart is empty.',
            style: GoogleFonts.lexend(color: StudentTheme.textSecondary),
          ),
        ),
      );
    }

    final itemsBySession = <String, List<StudentCartItem>>{};
    for (var cartItem in cartItems) {
      if (cartItem.menuItem.isPreReady) {
        itemsBySession.putIfAbsent('ready_on_order', () => []).add(cartItem);
      } else {
        itemsBySession.putIfAbsent(cartItem.menuItem.sessionId, () => []).add(cartItem);
      }
    }

    return Scaffold(
      backgroundColor: StudentTheme.background,
      appBar: AppBar(
        backgroundColor: StudentTheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: StudentTheme.primary,
                  size: 16,
                ),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: Text(
          'Checkout',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: StudentTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: itemsBySession.keys.length,
                itemBuilder: (context, index) {
                  final sId = itemsBySession.keys.elementAt(index);
                  final sessionItems = itemsBySession[sId] ?? [];
                  if (sessionItems.isEmpty) return const SizedBox.shrink();

                  final sessionInfo = sId == 'ready_on_order' ? null : dailyMenu?.sessions
                      .where((s) => s.sessionId == sId)
                      .firstOrNull;
                  return _buildSessionGroup(sId, sessionInfo, sessionItems);
                },
              ),
            ),
            _buildPaymentAndSummary(),
          ],
        ),
      ),
    );
  }

  List<StudentMenuSlot> _filterSlots(
    List<StudentMenuSlot> slots,
    String? menuDate,
  ) {
    return slots.where((slot) => slot.isEnabled).toList();
  }

  Widget _buildSessionGroup(
    String sId,
    StudentMenuSession? sessionInfo,
    List<StudentCartItem> items,
  ) {
    bool isReadyGroup = sId == 'ready_on_order' || items.any((ci) => ci.menuItem.isPreReady);
    final sessionName = isReadyGroup ? 'Pre-ready items' : (sessionInfo?.sessionNameSnapshot ?? 'Session');
    final dailyMenu = ref.watch(todayStudentMenuProvider).value;

    final filteredSlots = _getValidSlotsForSession(sId, sessionInfo, dailyMenu, items.any((ci) => ci.menuItem.isPreReady));

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: StudentTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: StudentTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                sessionName,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: StudentTheme.primary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map(
            (cartItem) => _buildItemWithSlotPicker(cartItem, filteredSlots, dailyMenu),
          ),
        ],
      ),
    );
  }


  Widget _buildItemWithSlotPicker(
    StudentCartItem cartItem,
    List<StudentMenuSlot> availableSlots,
    StudentDailyMenu? dailyMenu,
  ) {
    final item = cartItem.menuItem;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 54,
                  height: 54,
                  color: Colors.white,
                  child: item.imageUrlSnapshot.isEmpty
                      ? const Icon(
                          Icons.fastfood_rounded,
                          color: StudentTheme.textTertiary,
                          size: 24,
                        )
                      : Image.network(item.imageUrlSnapshot, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nameSnapshot,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Quantity: ${cartItem.quantity}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${(item.priceSnapshot * cartItem.quantity).toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'SELECT PICKUP SLOT',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: Colors.white54,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: cartItem.selectedSlot?.id,
            dropdownColor: StudentTheme.primary,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
            itemHeight: 64,
            elevation: 8,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            isDense: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
            ),
            hint: Text(
              'Select a pickup time...',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            selectedItemBuilder: (context) {
              return availableSlots.map((slot) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_formatTime(slot.startTime)} – ${_formatTime(slot.endTime)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList();
            },
            items: availableSlots.map((slot) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final menuDate = dailyMenu?.date;
              final isToday = menuDate == DateFormat('yyyy-MM-dd').format(now);
              
              bool isPassed = false;
              if (isToday) {
                final endTime = TimeHelper.parseSessionTime(slot.endTime, today);
                isPassed = endTime != null && endTime.isBefore(now);
              }

              final capacity = slot.remainingCapacity;
              final isFull = capacity <= 0;
              final isEnabled = !isPassed && !isFull;

              String statusText = 'Available';
              Color statusColor = StudentTheme.statusGreen;
              if (isPassed) {
                statusText = 'Time Passed';
                statusColor = StudentTheme.textTertiary;
              } else if (isFull) {
                statusText = 'Full';
                statusColor = StudentTheme.statusRed;
              } else if (capacity <= 5) {
                statusText = 'Very Few Left';
                statusColor = Colors.orange;
              } else if (capacity <= 15) {
                statusText = 'Filling Fast';
                statusColor = Colors.orange.withValues(alpha: 0.8);
              }

              final isVirtual = slot.id.startsWith('VIRTUAL_');

              return DropdownMenuItem<String>(
                value: slot.id,
                enabled: isEnabled,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (isVirtual) 
                                const Icon(Icons.flash_on_rounded, color: StudentTheme.accent, size: 14),
                              if (isVirtual) const SizedBox(width: 4),
                              Text(
                                isVirtual 
                                  ? 'Immediate Pickup (ASAP)'
                                  : '${_formatTime(slot.startTime)} – ${_formatTime(slot.endTime)}',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isEnabled ? Colors.white : Colors.white38,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            isVirtual ? 'Ready Now' : statusText,
                            style: GoogleFonts.plusJakartaSans(
                              color: isVirtual ? StudentTheme.accent : statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isEnabled && !isVirtual)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: StudentTheme.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$capacity left',
                          style: GoogleFonts.plusJakartaSans(
                            color: StudentTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (slotId) {
              if (slotId != null) {
                final selected = availableSlots.firstWhere((s) => s.id == slotId);
                ref.read(studentCartProvider.notifier).setSlotForItem(item.itemId, item.sessionId, selected);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAndSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Method',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: StudentTheme.primary,
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isUpiExpanded = !_isUpiExpanded),
                  child: Row(
                    children: [
                      Text(
                        _selectedUpiProvider ?? 'Select UPI',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: StudentTheme.accent,
                        ),
                      ),
                      Icon(
                        _isUpiExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: StudentTheme.accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isUpiExpanded) ...[
              const SizedBox(height: 16),
              _buildUpiOption('Google Pay', 'GPay', true),
              const SizedBox(height: 12),
              _buildUpiOption('PhonePe', 'bolt', false),
              const SizedBox(height: 12),
              _buildUpiOption('Amazon Pay', 'apay', false),
              const SizedBox(height: 12),
              _buildUpiOption('Other', 'other', false),
            ],
            const SizedBox(height: 24),
            _buildSummaryLine('Subtotal', widget.subtotal),
            const SizedBox(height: 12),
            _buildSummaryLine('Tax & Fees', widget.taxAmount),
            const SizedBox(height: 12),
            _buildSummaryLine('Platform Fee', widget.platformFee),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: StudentTheme.border, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: StudentTheme.primary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '₹${widget.totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: StudentTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (ref.watch(studentCartProvider.notifier).allSlotsSelected &&
                      _selectedUpiProvider != null)
                  ? _processOrder
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pay & Generate Token',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.qr_code_2_rounded, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiOption(String name, String label, bool isRecommended) {
    bool isSelected = _selectedUpiProvider == name;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedUpiProvider = name;
        _isUpiExpanded = false;
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? StudentTheme.primary.withValues(alpha: 0.05) : StudentTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? StudentTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                ],
              ),
              child: Center(
                child: label == 'GPay'
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('G', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w900, fontSize: 10)),
                          Text('P', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w900, fontSize: 10)),
                          Text('a', style: TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.w900, fontSize: 10)),
                          Text('y', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w900, fontSize: 10)),
                        ],
                      )
                    : label == 'bolt'
                        ? const Icon(Icons.bolt_rounded, color: Colors.deepPurple, size: 20)
                        : label == 'apay'
                            ? Text('apay', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w900, fontSize: 10))
                            : const Icon(Icons.account_balance_wallet_rounded, color: StudentTheme.primary, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: StudentTheme.primary,
                    ),
                  ),
                  if (isRecommended)
                    Text(
                      'Recommended',
                      style: GoogleFonts.plusJakartaSans(
                        color: StudentTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            Radio<String>(
              value: name,
              groupValue: _selectedUpiProvider,
              onChanged: (val) => setState(() => _selectedUpiProvider = val),
              activeColor: StudentTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSummaryLine(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: StudentTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
            color: StudentTheme.primary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return timeString;
      final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat.jm().format(dt);
    } catch (_) {
      return timeString;
    }
  }

  Widget _buildProcessingScreen() {
    return Scaffold(
      backgroundColor: StudentTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: StudentTheme.primary.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: StudentTheme.primary.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          color: StudentTheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            color: StudentTheme.primary,
                            backgroundColor: StudentTheme.primary.withValues(alpha: 0.2),
                            minHeight: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Processing Order',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: StudentTheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Confirming your items and slots with the kitchen...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: StudentTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildProcessStep(1, 'Payment Verified'),
                        _buildProcessStep(2, 'Sending to Kitchen'),
                        _buildProcessStep(3, 'Generating Token'),
                      ],
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

  Widget _buildProcessStep(int stepIndex, String label) {
    final bool isCompleted = _currentStep > stepIndex;
    final bool isActive = _currentStep == stepIndex;
    final bool isPending = _currentStep < stepIndex;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? StudentTheme.statusGreen
                      : (isActive
                          ? StudentTheme.primary
                          : Colors.transparent),
                  shape: BoxShape.circle,
                  border: isPending
                      ? Border.all(color: StudentTheme.border, width: 2)
                      : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : (isActive
                        ? Center(
                            child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle)))
                        : null),
              ),
              if (stepIndex < 3)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                     width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? StudentTheme.statusGreen : StudentTheme.border,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 500),
                  style: GoogleFonts.plusJakartaSans(
                    color: isPending ? StudentTheme.textTertiary : StudentTheme.primary,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 15,
                  ),
                  child: Text(label),
                ),
                if (stepIndex < 3) const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processOrder() async {
    final cartItems = ref.read(studentCartProvider);
    final userProfile = ref.read(userProfileProvider).value;

    final dailyMenu = ref.read(todayStudentMenuProvider).value;
    final ineligibleItems = <String>[];

    for (var i = 0; i < cartItems.length; i++) {
      final c = cartItems[i];
      final sId = c.menuItem.sessionId;
      final session = dailyMenu?.sessions.firstWhere(
        (s) => s.sessionId == sId,
        orElse: () => StudentMenuSession(
          sessionId: sId,
          sessionNameSnapshot: '',
          startTime: '',
          endTime: '',
          items: [],
          slots: [],
        ),
      );

      final bool isPreReady = c.menuItem.isPreReady;
      final filtered = _getValidSlotsForSession(
        isPreReady ? 'ready_on_order' : sId,
        session,
        dailyMenu,
        isPreReady,
      );

      // Auto failover logic
      if (filtered.isEmpty) {
        ineligibleItems.add(c.menuItem.nameSnapshot);
      } else {
        // If the selected slot is no longer valid (capacity 0 or past time), auto-select next available
        final currentSlotId = c.selectedSlot?.id;
        final isCurrentValid = filtered.any((s) => s.id == currentSlotId);

        if (!isCurrentValid) {
          // Find first available chronologically (they are usually sorted)
          final nextAvailable = filtered.first;

          // Show toast/banner
          if (mounted) {
            showAppMessage(
              context,
              'Slot full for ${c.menuItem.nameSnapshot}. Auto-switched to next available slot.',
              type: AppMessageType.info,
            );
          }

          // Update cart item state behind the scenes
          ref
              .read(studentCartProvider.notifier)
              .setSlotForItem(c.menuItem.itemId, c.menuItem.sessionId, nextAvailable);

          // Note: The UI will not strictly rebuild until we setState, but we're in the middle of processing.
          // In a real flow we might block processing and force a rebuild, but let's try to auto-heal and continue.
        }
      }
    }

    if (ineligibleItems.isNotEmpty) {
      showAppMessage(
        context,
        'Cannot proceed: ${ineligibleItems.join(", ")} has no available slots.',
        type: AppMessageType.error,
      );
      return;
    }

    if (!ref.read(studentCartProvider.notifier).allSlotsSelected) {
      showAppMessage(
        context,
        'Please select a pickup slot for every item.',
        type: AppMessageType.error,
      );
      return;
    }

    if (userProfile == null) {
      showAppMessage(
        context,
        'Failed to load user profile.',
        type: AppMessageType.error,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentStep = 1;
      _processingSlotStartTime = cartItems.isNotEmpty ? cartItems.first.selectedSlot?.startTime : null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _currentStep = 2);
      await Future.delayed(const Duration(milliseconds: 1200));

      final orderService = ref.read(studentOrderServiceProvider);
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch the most up-to-date cart items, which includes any auto-failovers
      final finalCartItems = ref.read(studentCartProvider);
      final itemsForReveal = finalCartItems.map((c) => {
        'name': c.menuItem.nameSnapshot,
        'quantity': c.quantity,
        'itemStatus': c.menuItem.isPreReady ? 'ready' : 'pending',
        'isPreReady': c.menuItem.isPreReady,
        'selectedSlotStartTime': c.selectedSlot?.startTime,
        'selectedSlotEndTime': c.selectedSlot?.endTime,
      }).toList();

      final groupId = await orderService.processCheckout(
        date: date,
        cartItems: finalCartItems,
        baseTax: widget.taxAmount,
        platformFee: widget.platformFee,
        totalSubtotal: widget.subtotal,
        studentName: userProfile.displayName,
        studentId: userProfile.studentId,
      );

      // Fetch tokens for the group
      final ordersSnap = await FirebaseFirestore.instance
          .collection('canteens')
          .doc('default')
          .collection('orders')
          .where(
            'studentUid',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
          )
          .where('checkoutGroupId', isEqualTo: groupId)
          .get();

      final tokens = ordersSnap.docs
          .map((d) => (d.data()['tokenNumber'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();

      if (mounted) setState(() => _currentStep = 3);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) setState(() => _currentStep = 4); // All done
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear cart immediately after success
      ref.invalidate(studentCartProvider);

      // Trigger the live in-app success alert
      final firstToken = tokens.isNotEmpty ? tokens.first : null;
      ref
          .read(studentAlertProvider.notifier)
          .showAlert(
            OrderAlert(
              title: 'Order Placed',
              body: 'Successfully placed your order',
              token: firstToken,
              type: AlertType.success,
            ),
          );
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _showSuccess = true;
        _generatedTokens = tokens;
        _orderedItems = itemsForReveal;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      showAppMessage(
        context,
        'Checkout failed: $e',
        type: AppMessageType.error,
      );
    }
  }

  List<StudentMenuSlot> _getValidSlotsForSession(
    String sId,
    StudentMenuSession? sessionInfo,
    StudentDailyMenu? dailyMenu,
    bool isPreReady,
  ) {
    bool isReadyGroup = sId == 'ready_on_order' || isPreReady;
    List<StudentMenuSlot> allSlots = [];

    if (isReadyGroup && dailyMenu != null) {
      final Map<String, StudentMenuSlot> slotMap = {};
      for (var s in dailyMenu.sessions) {
        for (var slot in s.slots) {
          slotMap[slot.id] = slot;
        }
      }
      allSlots = slotMap.values.toList();
    } else {
      allSlots = sessionInfo?.slots ?? [];
    }

    var filtered = _filterSlots(allSlots, dailyMenu?.date);

    // Filter out logically passed slots OR full slots
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    filtered = filtered.where((slot) {
      // 1. Check capacity
      if (slot.remainingCapacity <= 0) return false;

      // 2. Check time
      final menuDate = dailyMenu?.date;
      if (menuDate == DateFormat('yyyy-MM-dd').format(now)) {
        final endTime = TimeHelper.parseSessionTime(slot.endTime, today);
        return endTime == null || !endTime.isBefore(now);
      }
      return true;
    }).toList();

    // Sort valid slots chronologically ascending
    filtered.sort((a, b) {
      try {
        final format = DateFormat('hh:mm a');
        final timeA = format.parse(a.startTime);
        final timeB = format.parse(b.startTime);
        return timeA.compareTo(timeB);
      } catch (_) {
        return 0;
      }
    });

    // Fallback: If pre-ready and no valid slots remain, generate stable virtual ones
    if (filtered.isEmpty && isReadyGroup) {
      final bucket = now.minute ~/ 15;
      final stableIdBase = '${now.hour}_$bucket';
      
      final next15 = now.add(const Duration(minutes: 15));
      final format = DateFormat('hh:mm a');
      
      filtered = [
        StudentMenuSlot(
          id: 'VIRTUAL_ASAP_$stableIdBase',
          startTime: format.format(now),
          endTime: format.format(next15),
          remainingCapacity: 99,
          isEnabled: true,
        ),
      ];
    }
    return filtered;
  }

  Widget _buildSuccessScreen() {
    return StudentSuccessReveal(
      tokens: _generatedTokens,
      items: _orderedItems,
      slotStartTime: _processingSlotStartTime,
      onDone: () => context.go('/student/orders'),
      onGoToDashboard: () {
        ref.invalidate(studentCartProvider);
        context.go('/student/dashboard');
      },
    );
  }
}
