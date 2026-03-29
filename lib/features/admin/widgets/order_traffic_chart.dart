import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class OrderTrafficChart extends StatelessWidget {
  final Map<String, Map<String, Map<String, int>>> trafficData;

  const OrderTrafficChart({
    super.key,
    required this.trafficData,
  });

  @override
  Widget build(BuildContext context) {
    // We only need "This Week" data to plot New vs Repeat
    final thisWeek = trafficData['This Week'] ?? {};

    // Calculate max value for radar scaling
    double maxVal = 0;
    for (int i = 1; i <= 7; i++) {
      final data = thisWeek[i.toString()] ?? {'new': 0, 'repeat': 0};
      if (data['new']! > maxVal) maxVal = data['new']!.toDouble();
      if (data['repeat']! > maxVal) maxVal = data['repeat']!.toDouble();
    }
    
    // No mock data logic here as per user request
    if (maxVal == 0) maxVal = 10;
    else maxVal = maxVal * 1.2;

    // Generate datasets
    final List<RadarDataSet> dataSets = [
      // New Orders (Green)
      RadarDataSet(
        fillColor: const Color(0xFF10B981).withValues(alpha: 0.2),
        borderColor: const Color(0xFF10B981),
        entryRadius: 3,
        dataEntries: List.generate(7, (i) {
          double val = (thisWeek[(i + 1).toString()]?['new'] ?? 0).toDouble();
          return RadarEntry(value: val);
        }),
        borderWidth: 2,
      ),
      // Repeat Orders (Purple)
      RadarDataSet(
        fillColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
        borderColor: const Color(0xFF8B5CF6),
        entryRadius: 3,
        dataEntries: List.generate(7, (i) {
          double val = (thisWeek[(i + 1).toString()]?['repeat'] ?? 0).toDouble();
          return RadarEntry(value: val);
        }),
        borderWidth: 2,
      ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.change_history, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Order Traffic',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'This week',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: RadarChart(
              RadarChartData(
                dataSets: dataSets,
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.1,
                titleTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                getTitle: (index, angle) {
                  switch (index) {
                    case 0: return const RadarChartTitle(text: 'Mon');
                    case 1: return const RadarChartTitle(text: 'Tue');
                    case 2: return const RadarChartTitle(text: 'Wed');
                    case 3: return const RadarChartTitle(text: 'Thu');
                    case 4: return const RadarChartTitle(text: 'Fri');
                    case 5: return const RadarChartTitle(text: 'Sat');
                    case 6: return const RadarChartTitle(text: 'Sun');
                    default: return const RadarChartTitle(text: '');
                  }
                },
                tickCount: 3,
                ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
                tickBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1.5, strokeAlign: 0),
                gridBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
              ),
              swapAnimationDuration: const Duration(milliseconds: 600),
              swapAnimationCurve: Curves.easeInOutBack,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(const Color(0xFF10B981), 'New'),
              const SizedBox(width: 32),
              _buildLegend(const Color(0xFF8B5CF6), 'Repeat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
