import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ThreadAnalysisCard extends StatelessWidget {
  const ThreadAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    final lineChartBarData = LineChartBarData(
      isCurved: true,
      color: Colors.redAccent,
      barWidth: 2,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      spots: const [
        FlSpot(0, 30),
        FlSpot(1, 40),
        FlSpot(2, 35),
        FlSpot(3, 50), // highlighted point
        FlSpot(4, 45),
        FlSpot(5, 38),
        FlSpot(6, 42),
      ],
    );

    return Container(
      width: 345,
      height: 312,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.2),
        // gradient: const LinearGradient(
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        //   colors: [Color(0xFF4A90E2), Color(0xFF7B61FF)],
        // ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Thread Analysis:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,fontSize: 20),
          ),
          const SizedBox(height: 12),
          Row(
            children: ['1D', '5D', '1M', '1Y', 'ALL'].map((label) {
              bool isSelected = label == '1D';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.lightBlueAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [lineChartBarData],
                      extraLinesData: ExtraLinesData(verticalLines: [
                        VerticalLine(
                          x: 3,
                          color: Colors.greenAccent,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ]),
                      showingTooltipIndicators: [ShowingTooltipIndicators([
                        LineBarSpot(
                          lineChartBarData,
                          0,
                          const FlSpot(3, 50),
                        )
                      ])],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => Colors.redAccent,
                          // backgroundColor: Colors.redAccent,
                          getTooltipItems: (spots) {
                            return [
                              LineTooltipItem(
                                "Thread Reported:50",
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            ];
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 60,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(10, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: 10 + (i % 5) * 2,
                                width: 6,
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

