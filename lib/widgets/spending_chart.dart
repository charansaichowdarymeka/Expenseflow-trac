import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'app_text.dart';

class ChartPoint {
  final String label;
  final double value;
  ChartPoint(this.label, this.value);
}

class SpendingChart extends StatelessWidget {
  final List<ChartPoint> data;
  final String title;
  final String emptyLabel;
  final AppColors colors;
  final Color barColor;
  final Color activityColor;

  SpendingChart({
    super.key,
    this.data = const [],
    this.title = 'Spending trend',
    this.emptyLabel = 'No expense history yet.',
    required this.colors,
    Color? barColor,
    Color? activityColor,
  })  : barColor = barColor ?? colors.primary,
        activityColor = activityColor ?? colors.expense;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.isEmpty ? 1.0 : data.map((d) => d.value).fold<double>(1, (a, b) => b > a ? b : a);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.subheading(title, style: TextStyle(color: colors.text)),
              AppText.caption('Last 6 months', style: TextStyle(color: colors.secondary)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: data.isEmpty
                ? Center(child: AppText.caption(emptyLabel, style: TextStyle(color: colors.secondary)))
                : BarChart(
                    BarChartData(
                      maxY: maxValue,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= data.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: AppText.caption(data[index].label, style: TextStyle(color: colors.secondary)),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(enabled: false),
                      barGroups: [
                        for (int i = 0; i < data.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: data[i].value,
                              color: barColor,
                              width: 18,
                              borderRadius: BorderRadius.circular(999),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxValue,
                                color: colors.secondary.withValues(alpha: 0.13),
                              ),
                            ),
                          ]),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(barColor),
              const SizedBox(width: 6),
              AppText.caption('Trend', style: TextStyle(color: colors.secondary)),
              const SizedBox(width: 16),
              _legendDot(activityColor),
              const SizedBox(width: 6),
              AppText.caption('Activity', style: TextStyle(color: colors.secondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
