import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class SlotAnalysisChart extends StatefulWidget {
  final Map<String, dynamic> todayStats;
  final Map<String, dynamic> yesterdayStats;

  const SlotAnalysisChart({
    super.key,
    required this.todayStats,
    required this.yesterdayStats,
  });

  @override
  State<SlotAnalysisChart> createState() => _SlotAnalysisChartState();
}

class _SlotAnalysisChartState extends State<SlotAnalysisChart> {
  int _selectedIndex = 0; // 0: Revenue, 1: Orders, 2: Units

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, dynamic>> todaySessions = widget.todayStats['sessionStats'] ?? {};
    final Map<String, Map<String, dynamic>> yesterdaySessions = widget.yesterdayStats['sessionStats'] ?? {};

    // Collect all unique session names across both days
    Set<String> allSessions = {...todaySessions.keys, ...yesterdaySessions.keys};
    List<String> sortedSessions = allSessions.toList()..sort();
    
    // Determine max Y for the chart based on current selected tab
    double maxY = 0;
    List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < sortedSessions.length; i++) {
      String session = sortedSessions[i];
      double todayVal = 0;
      double yesterdayVal = 0;

      if (_selectedIndex == 0) {
        todayVal = (todaySessions[session]?['revenue'] ?? 0).toDouble();
        yesterdayVal = (yesterdaySessions[session]?['revenue'] ?? 0).toDouble();
      } else if (_selectedIndex == 1) {
        todayVal = (todaySessions[session]?['orders'] ?? 0).toDouble();
        yesterdayVal = (yesterdaySessions[session]?['orders'] ?? 0).toDouble();
      } else {
        todayVal = (todaySessions[session]?['units'] ?? 0).toDouble();
        yesterdayVal = (yesterdaySessions[session]?['units'] ?? 0).toDouble();
      }

      if (todayVal > maxY) maxY = todayVal;
      if (yesterdayVal > maxY) maxY = yesterdayVal;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: todayVal,
              color: const Color(0xFF10B981), // Green today
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: yesterdayVal,
              color: Colors.grey.shade300, // Grey yesterday
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          barsSpace: 4,
        ),
      );
    }

    double getNiceMaxY(double val) {
      if (val == 0) return _selectedIndex == 0 ? 1000 : 10;
      if (_selectedIndex == 0) {
        if (val <= 500) return 500;
        if (val <= 1000) return 1000;
        if (val <= 5000) return 5000;
        return val * 1.2;
      } else {
        if (val <= 5) return 5;
        if (val <= 10) return 10;
        if (val <= 50) return 50;
        return val * 1.2;
      }
    }

    maxY = getNiceMaxY(maxY);

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
                    child: const Icon(Icons.bar_chart, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Slot-wise Analysis',
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
                      'Today vs Yesterday',
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
          const SizedBox(height: 24),
          Row(
            children: [
              _buildTab('Revenue', 0),
              const SizedBox(width: 12),
              _buildTab('Orders', 1),
              const SizedBox(width: 12),
              _buildTab('Units', 2),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String session = sortedSessions[groupIndex];
                      bool isToday = rodIndex == 0;
                       String label = isToday ? 'Today' : 'Yesterday';
                       String prefix = _selectedIndex == 0 ? '₹' : '';
                      String valueFormatted = _selectedIndex == 0 ? rod.toY.toStringAsFixed(1) : rod.toY.toInt().toString();
                      return BarTooltipItem(
                        '$session\n$label: $prefix$valueFormatted',
                        GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= sortedSessions.length || value.toInt() < 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(
                            sortedSessions[value.toInt()],
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                         if (value == maxY) return const SizedBox.shrink();
                         String text = _selectedIndex == 0 ? value.toStringAsFixed(0) : value.toInt().toString();
                         if (_selectedIndex == 0) {
                           if (value >= 1000) text = '₹${(value / 1000).toStringAsFixed(1)}k';
                           else text = '₹$text';
                         }
                         return Text(
                          text,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                    dashArray: [5, 5]
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildLegend(const Color(0xFF10B981), 'Today'),
              const SizedBox(width: 24),
              _buildLegend(Colors.grey.shade300, 'Yesterday'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.white54,
          ),
        ),
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}
