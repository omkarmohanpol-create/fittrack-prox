import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/chart_service.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/progress_chart.dart';
import 'measurements_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ChartRange _range = ChartRange.d30;
  ChartMetric _metric = ChartMetric.workouts;
  ChartStyle _style = ChartStyle.line;

  // Pinch-to-zoom: the visible bucket range, null when showing everything.
  ChartWindow? _window;
  ChartWindow? _gestureStart;
  double _chartWidth = 1;
  double _panCarry = 0;

  void _setRange(ChartRange r) => setState(() {
        _range = r;
        _window = null;
      });

  Color get _color {
    switch (_metric) {
      case ChartMetric.workouts:
        return AppColors.workouts;
      case ChartMetric.calories:
        return AppColors.calories;
      case ChartMetric.minutes:
        return AppColors.steps;
      case ChartMetric.volume:
        return AppColors.cardio;
    }
  }

  String _format(double v, bool metric) {
    switch (_metric) {
      case ChartMetric.workouts:
        return v.round().toString();
      case ChartMetric.calories:
        return '${Formatters.compact(v)} kcal';
      case ChartMetric.minutes:
        return Formatters.duration(v.round());
      case ChartMetric.volume:
        return Formatters.weight(v, metric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<WorkoutProvider>().workouts;
    final metricUnits = context.watch<SettingsProvider>().useMetric;
    final full = ChartService.build(workouts, _range, _metric);
    final window = _window ?? ChartWindow.full(full.values.length);
    final series = window.isFull(full.values.length)
        ? full
        : full.window(window.start, window.end);
    final zoomable = full.values.length > 7;
    final bucketWord = switch (_range) {
      ChartRange.d7 || ChartRange.d30 => 'day',
      ChartRange.d90 => 'week',
      ChartRange.y1 => 'month',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MeasurementsScreen()),
            ),
            icon: const Icon(Icons.monitor_weight_outlined),
            label: const Text('Body'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<ChartRange>(
                  showSelectedIcon: false,
                  segments: [
                    for (final r in ChartRange.values)
                      ButtonSegment(value: r, label: Text(r.label)),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => _setRange(s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final m in ChartMetric.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: _metric == m,
                  onSelected: (_) => setState(() => _metric = m),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: SegmentedButton<ChartStyle>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ChartStyle.line,
                        icon: Icon(Icons.show_chart_rounded),
                        tooltip: 'Line chart',
                      ),
                      ButtonSegment(
                        value: ChartStyle.bar,
                        icon: Icon(Icons.bar_chart_rounded),
                        tooltip: 'Bar chart',
                      ),
                    ],
                    selected: {_style},
                    onSelectionChanged: (s) => setState(() => _style = s.first),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    _chartWidth = constraints.maxWidth;
                    final chart = ProgressChart(
                      series: series,
                      style: _style,
                      color: _color,
                      height: 240,
                    );
                    if (!zoomable) return chart;
                    final length = full.values.length;
                    return GestureDetector(
                      onDoubleTap: () => setState(() => _window = null),
                      onScaleStart: (_) {
                        _gestureStart = window;
                        _panCarry = 0;
                      },
                      onScaleUpdate: (d) {
                        final start = _gestureStart ?? window;
                        if (d.pointerCount >= 2) {
                          final focus = d.localFocalPoint.dx / _chartWidth;
                          setState(() =>
                              _window = start.zoom(length, d.scale, focus));
                        } else if (!window.isFull(length)) {
                          // One finger drags a zoomed-in chart sideways;
                          // dragging right shows earlier days.
                          _panCarry -=
                              d.focalPointDelta.dx / (_chartWidth / window.size);
                          final whole = _panCarry.truncate();
                          if (whole != 0) {
                            _panCarry -= whole;
                            setState(() => _window = window.pan(length, whole));
                          }
                        }
                      },
                      child: chart,
                    );
                  },
                ),
                if (zoomable)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      window.isFull(full.values.length)
                          ? 'Pinch to zoom'
                          : 'Drag to move, double-tap to reset',
                      style: TextStyle(fontSize: 11, color: context.faint),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Summary(
                  label: 'Total',
                  value: _format(series.total, metricUnits),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Summary(
                  label: 'Avg / $bucketWord',
                  value: _format(series.average, metricUnits),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Summary(
                  label: 'Best $bucketWord',
                  value: _format(series.maxValue, metricUnits),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;

  const _Summary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: context.muted)),
        ],
      ),
    );
  }
}
