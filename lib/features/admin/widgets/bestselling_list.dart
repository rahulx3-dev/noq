import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class BestsellingList extends StatelessWidget {
  final List<dynamic> itemSales;

  const BestsellingList({
    super.key,
    required this.itemSales,
  });

  @override
  Widget build(BuildContext context) {
    final topItems = itemSales.take(3).toList();
    // Real data only policy
    List<dynamic> displayItems = topItems;

    // Define colors for the mini bar charts per row (Green, Purple, Pink)
    final List<Color> rowColors = [
      const Color(0xFF10B981), // Green
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF302F2C), // Matches Student Module
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Bestselling',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...List.generate(displayItems.length, (index) {
            final item = displayItems[index] as Map<String, dynamic>;
            final name = item['name'] ?? 'Unknown';
            final session = item['session'] ?? 'All Day';
            final qty = item['quantity'] ?? 0;
            final color = rowColors[index % rowColors.length];
            
            IconData itemIcon = Icons.fastfood;
            if (name.toLowerCase().contains('biryani')) itemIcon = Icons.rice_bowl;
            if (name.toLowerCase().contains('meal')) itemIcon = Icons.local_dining;
            if (name.toLowerCase().contains('noodle')) itemIcon = Icons.ramen_dining;

            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Center(
                      child: Icon(itemIcon, color: color, size: 20),
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
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$session · $qty sold',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildMiniBarChart(color, qty),
                ],
              ),
            );
          }),
          if (displayItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  'No sales data for today',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Generates a mock mini bar chart based on a seed (quantity)
  Widget _buildMiniBarChart(Color color, int qty) {
    math.Random random = math.Random(qty);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(10, (index) {
        // Generate random heights between 4 and 24
        double height = 4.0 + random.nextInt(20);
        return Container(
          width: 4,
          height: height,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: index % 2 == 0 ? 1.0 : 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
