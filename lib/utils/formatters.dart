import 'package:intl/intl.dart';

class Formatters {
  static const double _kgToLb = 2.2046226218;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String shortDay(DateTime d) => DateFormat('E').format(d);

  static String longDate(DateTime d) => DateFormat('EEE, d MMM').format(d);

  /// "Today", "Yesterday", or [longDate] (plus the year if it is not this year).
  static String relativeDay(DateTime d, {DateTime? now}) {
    final day = dateOnly(d);
    final today = dateOnly(now ?? DateTime.now());
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (day.year != today.year) {
      return DateFormat('EEE, d MMM yyyy').format(day);
    }
    return longDate(day);
  }

  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// 1500 -> "1.5 L", 250 -> "250 ml"
  static String volumeMl(int ml) {
    if (ml < 1000) return '$ml ml';
    final litres = ml / 1000;
    final text = litres == litres.roundToDouble()
        ? litres.toStringAsFixed(0)
        : litres.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '$text L';
  }

  static double kgToDisplay(double kg, bool metric) =>
      metric ? kg : kg * _kgToLb;

  static double displayToKg(double value, bool metric) =>
      metric ? value : value / _kgToLb;

  static String weight(double kg, bool metric) {
    final v = kgToDisplay(kg, metric);
    final text = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return '$text ${metric ? 'kg' : 'lb'}';
  }

  static const double _cmPerInch = 2.54;

  static double cmToDisplay(double cm, bool metric) =>
      metric ? cm : cm / _cmPerInch;

  static double displayToCm(double value, bool metric) =>
      metric ? value : value * _cmPerInch;

  /// 80 -> "80", 80.25 -> "80.3"
  static String decimal(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String length(double cm, bool metric) =>
      '${decimal(cmToDisplay(cm, metric))} ${metric ? 'cm' : 'in'}';

  /// 75 s -> "01:15", 3725 s -> "1:02:05"
  static String clock(Duration d) {
    final total = d.isNegative ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// Minutes to log for a timed workout: rounded up, at least 1.
  static int minutesFor(Duration d) {
    final m = (d.inSeconds / 60).ceil();
    return m < 1 ? 1 : m;
  }

  static String compact(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
