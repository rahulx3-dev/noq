import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/themes/admin_theme.dart';

class LeftoverCarryPopup extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String fromSessionName;
  final String toSessionName;
  final Function(List<Map<String, dynamic>> selectedItems) onConfirm;
  final VoidCallback onDismiss;

  const LeftoverCarryPopup({
    super.key,
    required this.items,
    required this.fromSessionName,
    required this.toSessionName,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<LeftoverCarryPopup> createState() => _LeftoverCarryPopupState();
}

class _LeftoverCarryPopupState extends State<LeftoverCarryPopup> {
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    // Select all by default
    for (var item in widget.items) {
      _selectedItemIds.add(item['itemId'] as String);
    }
  }

  bool get _allSelected => _selectedItemIds.length == widget.items.length;

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        for (var item in widget.items) {
          _selectedItemIds.add(item['itemId'] as String);
        }
      } else {
        _selectedItemIds.clear();
      }
    });
  }

  void _toggleItem(String id, bool? value) {
    setState(() {
      if (value == true) {
        _selectedItemIds.add(id);
      } else {
        _selectedItemIds.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'SESSION END',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.green[700],
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onDismiss,
                        icon: Icon(Icons.close, color: Colors.grey[400]),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stock Carryover',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AdminTheme.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AdminTheme.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Select items to move from '),
                        TextSpan(
                          text: widget.fromSessionName,
                          style: const TextStyle(
                              color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' to '),
                        TextSpan(
                          text: widget.toSessionName,
                          style: const TextStyle(
                              color: Color(0xFF13ECC8), fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Select All Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.symmetric(
                  horizontal: BorderSide(color: Colors.grey[100]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REMAINING ITEMS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[700],
                      letterSpacing: 1.0,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'SELECT ALL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[500],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch.adaptive(
                        value: _allSelected,
                        onChanged: _toggleAll,
                        activeThumbColor: const Color(0xFF13ECC8),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Items List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shrinkWrap: true,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final id = item['itemId'] as String;
                  final isSelected = _selectedItemIds.contains(id);
                  final stock = item['stock'] as int? ?? 0;
                  final sold = item['soldQuantity'] as int? ?? 0;
                  final remaining = stock - sold;

                  return InkWell(
                    onTap: () => _toggleItem(id, !isSelected),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.transparent : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.fastfood_outlined,
                                color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Unknown',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: AdminTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '$remaining Left in stock',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: isSelected,
                            onChanged: (val) => _toggleItem(id, val),
                            activeColor: const Color(0xFF13ECC8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final selected = widget.items
                          .where((it) => _selectedItemIds.contains(it['itemId']))
                          .toList();
                      widget.onConfirm(selected);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13ECC8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF13ECC8).withValues(alpha: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ADD TO NEXT SESSION',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ITEMS NOT SELECTED WILL BE MARKED AS \'WASTE\'',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[400],
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
