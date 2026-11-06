import 'package:intl/intl.dart';

import '../models/models.dart';
import '../utils/formatters.dart';

enum ChartRange {
  d7('7D'),
  d30('30D'),
  d90('90D'),
  y1('1Y');

  final String label;
  const ChartRange(this.label);
}

enum ChartMetric {
  workouts('Workouts'),
  calories('Calories'),
  minutes('Minutes'),
  volume('Volume');

  final String label;
  const ChartMetric(this.label);
}

class ChartSeries {
  final List<String> labels;
  final List<double> values;

  const ChartSeries(this.labels, this.values);

  double get total => values.fold(0.0, (a, b) => a + b);
  double get average => values.isEmpty ? 0 : total / values.length;
  double get maxValue =>
      values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

  /// The buckets from [start] (inclusive) to [end] (exclusive).
  ChartSeries window(int start, int end) =>
      ChartSeries(labels.sublist(start, end), values.sublist(start, end));
}

/// Visible bucket range of a zoomed chart: [start] inclusive, [end] exclusive.
class ChartWindow {
  final int start;
  final int end;

  const ChartWindow(this.start, this.end);

  const ChartWindow.full(int length) : this(0, length);

  int get size => end - start;

  bool isFull(int length) => start == 0 && end == length;

  /// Pinch zoom. [scale] > 1 zooms in. [focus] is where the fingers are,
  /// from 0 (left edge) to 1 (right edge); that point stays put.
  ChartWindow zoom(int length, double scale, double focus, {int minSize = 4}) {
    final smallest = length < minSize ? length : minSize;
    final newSize = (size / scale).round().clamp(smallest, length);
    final anchor = start + focus.clamp(0.0, 1.0) * size;
    final s = (anchor - focus.clamp(0.0, 1.0) * newSize)
        .round()
        .clamp(0, length - newSize);
    return ChartWindow(s, s + newSize);
  }

  /// Moves the window by [buckets] (positive = later), staying in range.
  ChartWindow pan(int length, int buckets) {
    final s = (start + buckets).clamp(0, length - size);
    return ChartWindow(s, s + size);
  }

  @override
  bool operator ==(Object other) =>
      other is ChartWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ChartWindow($start, $end)';
}

class ChartService {
  /// Buckets: 7D / 30D = daily, 90D = 13 weekly buckets, 1Y = 12 monthly buckets.
  static ChartSeries build(
    List<Workout> workouts,
    ChartRange range,
    ChartMetric metric, {
    DateTime? now,
  }) {
    final today = Formatters.dateOnly(now ?? DateTime.now());
    late final int buckets;
    late final int Function(DateTime) indexOf;
    late final List<String> labels;

    switch (range) {
      case ChartRange.d7:
      case ChartRange.d30:
        buckets = range == ChartRange.d7 ? 7 : 30;
        final start = today.subtract(Duration(days: buckets - 1));
        indexOf = (d) => Formatters.dateOnly(d).difference(start).inDays;
        labels = List.generate(buckets, (i) {
          final day = start.add(Duration(days: i));
          if (range == ChartRange.d7) return DateFormat('E').format(day);
          return i % 5 == 0 ? DateFormat('d MMM').format(day) : '';
        });
      case ChartRange.d90:
        buckets = 13;
        final start = today.subtract(const Duration(days: 13 * 7 - 1));
        indexOf = (d) => Formatters.dateOnly(d).difference(start).inDays ~/ 7;
        labels = List.generate(buckets, (i) {
          final day = start.add(Duration(days: i * 7));
          return i % 3 == 0 ? DateFormat('d MMM').format(day) : '';
        });
      case ChartRange.y1:
        buckets = 12;
        int monthIndex(DateTime d) => d.year * 12 + d.month;
        indexOf = (d) => monthIndex(d) - monthIndex(today) + 11;
        labels = List.generate(buckets, (i) {
          final month = DateTime(today.year, today.month - (11 - i));
          return DateFormat('MMM').format(month);
        });
    }

    final values = List<double>.filled(buckets, 0);
    for (final w in workouts) {
      final i = indexOf(w.date);
      if (i < 0 || i >= buckets) continue;
      values[i] += _valueOf(w, metric);
    }
    return ChartSeries(labels, values);
  }

  static double _valueOf(Workout w, ChartMetric metric) {
    switch (metric) {
      case ChartMetric.workouts:
        return 1;
      case ChartMetric.calories:
        return w.caloriesBurned.toDouble();
      case ChartMetric.minutes:
        return w.durationMinutes.toDouble();
      case ChartMetric.volume:
        return w.volume;
    }
  }
}
