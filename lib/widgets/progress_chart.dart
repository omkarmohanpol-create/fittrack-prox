import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/chart_service.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

enum ChartStyle { line, bar }

/// Line / bar chart with gradient fill, subtle grid and dark tooltips (DESIGN.md).
class ProgressChart extends StatelessWidget {
  final ChartSeries series;
  final ChartStyle style;
  final Color color;
  final double height;

  const ProgressChart({
    super.key,
    required this.series,
    this.style = ChartStyle.bar,
    this.color = AppColors.primary,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = series.maxValue <= 0 ? 4.0 : series.maxValue * 1.2;
    final labelStyle = TextStyle(fontSize: 10, color: context.faint);
    final grid = FlGridData(
      drawVerticalLine: false,
      horizontalInterval: maxY / 4,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: context.borderColor.withOpacity(0.6), strokeWidth: 1),
    );
    final titles = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          interval: maxY / 4,
          getTitlesWidget: (value, meta) {
            if (value == meta.max) return const SizedBox.shrink();
            return Text(Formatters.compact(value), style: labelStyle);
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= series.labels.length || value != i.toDouble()) {
              return const SizedBox.shrink();
            }
            final text = series.labels[i];
            if (text.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text, style: labelStyle),
            );
          },
        ),
      ),
    );

    final tooltipBg = context.isDark ? AppColors.background : Colors.white;

    return SizedBox(
      height: height,
      child: style == ChartStyle.bar
          ? BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                gridData: grid,
                borderData: FlBorderData(show: false),
                titlesData: titles,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => tooltipBg,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      Formatters.compact(rod.toY),
                      TextStyle(
                        color: context.isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < series.values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: series.values[i],
                          width: series.values.length > 14 ? 6 : 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.55), color],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
            )
          : LineChart(
              LineChartData(
                minX: 0,
                maxX: (series.values.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: grid,
                borderData: FlBorderData(show: false),
                titlesData: titles,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => tooltipBg,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          Formatters.compact(s.y),
                          TextStyle(
                            color:
                                context.isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < series.values.length; i++)
                        FlSpot(i.toDouble(), series.values[i]),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    preventCurveOverShooting: true,
                    barWidth: 3,
                    color: color,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.35), color.withOpacity(0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
            ),
    );
  }
}
