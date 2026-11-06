import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fittrack_pro/models/models.dart';
import 'package:fittrack_pro/providers/workout_provider.dart';
import 'package:fittrack_pro/services/chart_service.dart';
import 'package:fittrack_pro/utils/formatters.dart';
import 'package:fittrack_pro/utils/validators.dart';

Workout _workout(DateTime date, {int minutes = 30, int kcal = 200}) => Workout(
      id: newLocalId(),
      type: 'strength',
      name: 'Test',
      date: date,
      durationMinutes: minutes,
      caloriesBurned: kcal,
      exercises: const [
        WorkoutExercise(name: 'Squat', sets: 3, reps: 5, weightKg: 100),
      ],
    );

void main() {
  group('Formatters', () {
    test('duration', () {
      expect(Formatters.duration(45), '45 min');
      expect(Formatters.duration(60), '1h');
      expect(Formatters.duration(65), '1h 05m');
    });

    test('volumeMl', () {
      expect(Formatters.volumeMl(250), '250 ml');
      expect(Formatters.volumeMl(1000), '1 L');
      expect(Formatters.volumeMl(1500), '1.5 L');
      expect(Formatters.volumeMl(2250), '2.25 L');
    });

    test('unit conversion round-trips', () {
      final lb = Formatters.kgToDisplay(100, false);
      expect(lb, closeTo(220.46, 0.01));
      expect(Formatters.displayToKg(lb, false), closeTo(100, 0.0001));
      expect(Formatters.weight(80, true), '80 kg');
    });

    test('isoDate', () {
      expect(Formatters.isoDate(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('relativeDay', () {
      final now = DateTime(2026, 6, 15, 21, 30);
      expect(Formatters.relativeDay(DateTime(2026, 6, 15, 8), now: now), 'Today');
      expect(Formatters.relativeDay(DateTime(2026, 6, 14), now: now), 'Yesterday');
      expect(Formatters.relativeDay(DateTime(2026, 6, 10), now: now), 'Wed, 10 Jun');
      expect(Formatters.relativeDay(DateTime(2025, 12, 31), now: now),
          'Wed, 31 Dec 2025');
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('password', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('long-enough'), isNull);
    });

    test('optional numbers', () {
      expect(Validators.optionalInt(''), isNull);
      expect(Validators.optionalInt('12'), isNull);
      expect(Validators.optionalInt('-1'), isNotNull);
      expect(Validators.optionalNumber('72.5'), isNull);
      expect(Validators.optionalNumber('abc'), isNotNull);
    });
  });

  group('Workout model', () {
    test('volume is sets x reps x kg', () {
      expect(_workout(DateTime(2026, 1, 1)).volume, 1500);
    });

    test('fromJson reads nested exercises', () {
      final w = Workout.fromJson({
        'id': 'abc',
        'type': 'cardio',
        'name': 'Run',
        'date': '2026-01-05',
        'duration_minutes': 40,
        'calories_burned': 400,
        'workout_exercises': [
          {'exercise_name': 'Treadmill', 'sets': 1, 'reps': 1, 'weight_kg': 0},
        ],
      });
      expect(w.isCardio, isTrue);
      expect(w.exercises.single.name, 'Treadmill');
      expect(w.date, DateTime(2026, 1, 5));
    });
  });

  group('ChartService', () {
    final now = DateTime(2026, 6, 15);

    test('7D buckets by day, today is the last bucket', () {
      final s = ChartService.build(
        [_workout(now), _workout(now), _workout(DateTime(2026, 6, 13))],
        ChartRange.d7,
        ChartMetric.workouts,
        now: now,
      );
      expect(s.values.length, 7);
      expect(s.values.last, 2);
      expect(s.values[4], 1); // 13 June = two days before today
      expect(s.total, 3);
    });

    test('values outside the range are ignored', () {
      final s = ChartService.build(
        [_workout(DateTime(2026, 1, 1))],
        ChartRange.d7,
        ChartMetric.workouts,
        now: now,
      );
      expect(s.total, 0);
    });

    test('90D uses 13 weekly buckets', () {
      final s = ChartService.build(
        [_workout(now), _workout(now.subtract(const Duration(days: 80)))],
        ChartRange.d90,
        ChartMetric.minutes,
        now: now,
      );
      expect(s.values.length, 13);
      expect(s.values.last, 30);
      expect(s.total, 60);
    });

    test('1Y uses 12 monthly buckets ending this month', () {
      final s = ChartService.build(
        [_workout(now), _workout(DateTime(2025, 7, 20))],
        ChartRange.y1,
        ChartMetric.calories,
        now: now,
      );
      expect(s.values.length, 12);
      expect(s.values.last, 200);
      expect(s.values.first, 200); // July 2025 is 11 months back
    });

    test('volume metric sums sets x reps x kg', () {
      final s = ChartService.build(
        [_workout(now)],
        ChartRange.d7,
        ChartMetric.volume,
        now: now,
      );
      expect(s.total, 1500);
    });
  });

  group('Backdated workouts (guest mode)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a backdated workout lands in date order, newest first', () async {
      final p = WorkoutProvider();
      final today = Formatters.dateOnly(DateTime.now());
      final threeDaysAgo = today.subtract(const Duration(days: 3));
      final yesterday = today.subtract(const Duration(days: 1));

      expect(await p.add(_workout(today)), isNull);
      expect(await p.add(_workout(threeDaysAgo)), isNull);
      expect(await p.add(_workout(yesterday)), isNull);

      expect(p.workouts.map((w) => w.date).toList(),
          [today, yesterday, threeDaysAgo]);
    });

    test('backdating into the gap extends the streak', () async {
      final p = WorkoutProvider();
      final today = Formatters.dateOnly(DateTime.now());
      await p.add(_workout(today));
      await p.add(_workout(today.subtract(const Duration(days: 2))));
      expect(p.currentStreak, 1);

      await p.add(_workout(today.subtract(const Duration(days: 1))));
      expect(p.currentStreak, 3);
    });

    test('backdated workouts are saved on the device', () async {
      final p = WorkoutProvider();
      final lastWeek =
          Formatters.dateOnly(DateTime.now()).subtract(const Duration(days: 7));
      await p.add(_workout(lastWeek));

      final reloaded = WorkoutProvider();
      await reloaded.load();
      expect(reloaded.workouts.single.date, lastWeek);
    });
  });

  group('Local persistence', () {
    test('Workout survives toLocalJson -> JSON text -> fromJson', () {
      final w = _workout(DateTime(2026, 3, 7), minutes: 45, kcal: 310);
      final back = Workout.fromJson(
        jsonDecode(jsonEncode(w.toLocalJson())) as Map<String, dynamic>,
      );
      expect(back.id, w.id);
      expect(back.type, 'strength');
      expect(back.date, DateTime(2026, 3, 7));
      expect(back.durationMinutes, 45);
      expect(back.caloriesBurned, 310);
      expect(back.exercises.single.name, 'Squat');
      expect(back.volume, 1500);
    });

    test('WaterLog survives a JSON round trip', () {
      final log = WaterLog(
        id: 'local-1',
        amountMl: 250,
        date: DateTime(2026, 3, 7),
      );
      final back = WaterLog.fromJson(
        jsonDecode(jsonEncode(log.toLocalJson())) as Map<String, dynamic>,
      );
      expect(back.id, 'local-1');
      expect(back.amountMl, 250);
      expect(back.date, DateTime(2026, 3, 7));
    });
  });
}
