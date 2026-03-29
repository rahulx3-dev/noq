import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../app/themes/student_theme.dart';
import '../providers/student_cart_provider.dart';

class StudentCartScreen extends ConsumerWidget {
  const StudentCartScreen({super.key});

  static const double gstFees = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(studentCartProvider);

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
          'Your Cart',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: StudentTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE5E7EB), // gray-200
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Consumer(
                  builder: (context, ref, _) {
                    final profile = ref.watch(userProfileProvider).value;
                    if (profile?.imageUrl?.isNotEmpty ?? false) {
                      return Image.network(
                        profile!.imageUrl!,
                        fit: BoxFit.cover,
                      );
                    }
                    return const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: cartItems.isEmpty
          ? _buildEmptyCart(context)
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final cartItem = cartItems[index];
                      return _buildCartItemCard(context, ref, cartItem);
                    },
                  ),
                ),
                _buildBottomSummary(context, ref, cartItems.isNotEmpty),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: StudentTheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: StudentTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your Cart is Empty',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: StudentTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add some snacks to your cart\nto see them here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: StudentTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Browse Menu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(
    BuildContext context,
    WidgetRef ref,
    StudentCartItem cartItem,
  ) {
    final item = cartItem.menuItem;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.imageUrlSnapshot.isNotEmpty
                  ? Image.network(
                      item.imageUrlSnapshot,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: StudentTheme.surface,
                      child: const Icon(
                        Icons.fastfood,
                        color: StudentTheme.textTertiary,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.nameSnapshot,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: StudentTheme.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      // Remove Icon
                      GestureDetector(
                        onTap: () => ref
                            .read(studentCartProvider.notifier)
                            .removeFromCart(item.itemId, item.sessionId),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: StudentTheme.statusRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: StudentTheme.statusRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${item.priceSnapshot.toStringAsFixed(0)} each',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: StudentTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: StudentTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildQtyBtn(
                              Icons.remove,
                              () => ref
                                  .read(studentCartProvider.notifier)
                                  .decrementQuantity(item.itemId, item.sessionId),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                "${cartItem.quantity}",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: StudentTheme.primary,
                                ),
                              ),
                            ),
                            _buildQtyBtn(
                              Icons.add,
                              () {
                                if (cartItem.quantity < item.remainingStock) {
                                  ref.read(studentCartProvider.notifier).addToCart(item);
                                }
                              },
                              isAdd: true,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${(item.priceSnapshot * cartItem.quantity).toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: StudentTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap, {bool isAdd = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isAdd ? StudentTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isAdd ? Colors.white : StudentTheme.primary,
        ),
      ),
    );
  }

  Widget _buildBottomSummary(
    BuildContext context,
    WidgetRef ref,
    bool hasItems,
  ) {
    if (!hasItems) return const SizedBox.shrink();

    final subtotal = ref.watch(studentCartProvider.notifier).subtotal;
    final total = subtotal + gstFees;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow('Subtotal', subtotal),
          const SizedBox(height: 12),
          _buildSummaryRow('GST Fees', gstFees),
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
                '₹${total.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: StudentTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              context.push(
                '/student/checkout',
                extra: {
                  'subtotal': subtotal,
                  'taxAmount': gstFees,
                  'platformFee': 0.0,
                  'totalAmount': total,
                },
              );
            },
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
                  'Select Pickup Slot',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: StudentTheme.textSecondary,
          ),
        ),
        Text(
          '₹${value.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: StudentTheme.primary,
          ),
        ),
      ],
    );
  }
}
