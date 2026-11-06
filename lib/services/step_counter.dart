import '../utils/formatters.dart';

/// Turns the phone's step sensor into steps per day.
///
/// The sensor (Android TYPE_STEP_COUNTER) reports one total since the phone
/// last started, not steps per day. This keeps a baseline for the current day
/// and handles two cases:
///  * A new day: steps since the last reading count towards the new day, so
///    no steps are lost when the app was closed overnight (some evening steps
///    can land on the next day instead).
///  * A restart: the total drops back towards zero, so what was counted so far
///    today is kept as an offset.
class StepCounterState {
  final DateTime day;
  final int base; // sensor total the day's count starts from
  final int offset; // steps counted today before a restart
  final int last; // last sensor total seen

  const StepCounterState({
    required this.day,
    required this.base,
    required this.offset,
    required this.last,
  });

  int get steps {
    final s = offset + (last - base);
    return s < 0 ? 0 : s;
  }

  StepCounterState apply(int total, DateTime at) {
    final d = Formatters.dateOnly(at);
    if (d.isAfter(day)) {
      // Restart overnight: start from zero; otherwise from the last reading.
      final start = total < last ? 0 : last;
      return StepCounterState(day: d, base: start, offset: 0, last: total);
    }
    if (total < last) {
      return StepCounterState(day: day, base: 0, offset: steps, last: total);
    }
    return StepCounterState(day: day, base: base, offset: offset, last: total);
  }

  /// State for the first reading ever: counting starts now.
  factory StepCounterState.first(int total, DateTime at) => StepCounterState(
        day: Formatters.dateOnly(at),
        base: total,
        offset: 0,
        last: total,
      );

  Map<String, dynamic> toJson() => {
        'day': Formatters.isoDate(day),
        'base': base,
        'offset': offset,
        'last': last,
      };

  factory StepCounterState.fromJson(Map<String, dynamic> j) => StepCounterState(
        day: DateTime.parse(j['day'] as String),
        base: (j['base'] as num).toInt(),
        offset: (j['offset'] as num).toInt(),
        last: (j['last'] as num).toInt(),
      );
}
