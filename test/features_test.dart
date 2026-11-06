import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fittrack_pro/models/models.dart';
import 'package:fittrack_pro/providers/exercise_provider.dart';
import 'package:fittrack_pro/providers/measurement_provider.dart';
import 'package:fittrack_pro/providers/steps_provider.dart';
import 'package:fittrack_pro/providers/water_provider.dart';
import 'package:fittrack_pro/providers/workout_provider.dart';
import 'package:fittrack_pro/services/chart_service.dart';
import 'package:fittrack_pro/services/local_store.dart';
import 'package:fittrack_pro/services/step_counter.dart';
import 'package:fittrack_pro/utils/formatters.dart';

Workout _w(String id, DateTime date, {String name = 'Test'}) => Workout(
      id: id,
      type: 'strength',
      name: name,
      date: date,
      durationMinutes: 30,
      caloriesBurned: 200,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('newUuid', () {
    test('is a version 4 UUID', () {
      final id = newUuid();
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue,
        reason: id,
      );
      expect(isLocalId(id), isFalse);
    });

    test('does not repeat', () {
      expect({for (var i = 0; i < 1000; i++) newUuid()}.length, 1000);
    });
  });

  group('Workout.toSaveParams', () {
    test('matches what save_workout reads', () {
      final w = Workout(
        id: 'abc',
        type: 'strength',
        name: 'Push',
        date: DateTime(2026, 11, 5),
        durationMinutes: 45,
        caloriesBurned: 300,
        exercises: const [
          WorkoutExercise(name: 'Bench press', sets: 3, reps: 5, weightKg: 80),
          WorkoutExercise(name: 'Dip', sets: 3, reps: 10, weightKg: 0),
        ],
      );
      final p = w.toSaveParams();
      final workout = p['p_workout'] as Map<String, dynamic>;
      final exercises = p['p_exercises'] as List;
      expect(workout['id'], 'abc');
      expect(workout['date'], '2026-11-05');
      expect(workout.containsKey('user_id'), isFalse); // set by the server
      expect(exercises.length, 2);
      expect((exercises[1] as Map)['exercise_name'], 'Dip');
      expect((exercises[1] as Map)['order_index'], 1);
    });
  });

  group('Formatters (new)', () {
    test('clock', () {
      expect(Formatters.clock(const Duration(seconds: 75)), '01:15');
      expect(Formatters.clock(const Duration(seconds: 3725)), '1:02:05');
      expect(Formatters.clock(const Duration(seconds: -3)), '00:00');
    });

    test('minutesFor rounds up and is at least 1', () {
      expect(Formatters.minutesFor(const Duration(seconds: 10)), 1);
      expect(Formatters.minutesFor(const Duration(minutes: 30)), 30);
      expect(Formatters.minutesFor(const Duration(minutes: 30, seconds: 1)), 31);
    });

    test('lengths', () {
      expect(Formatters.length(80, true), '80 cm');
      expect(Formatters.length(2.54 * 31.5, false), '31.5 in');
      expect(Formatters.displayToCm(10, false), closeTo(25.4, 1e-9));
    });
  });

  group('ChartWindow', () {
    test('zooming in keeps the point under the fingers', () {
      const full = ChartWindow.full(30);
      final z = full.zoom(30, 2, 1.0); // pinch at the right edge
      expect(z, const ChartWindow(15, 30));
      final mid = full.zoom(30, 3, 0.5);
      expect(mid, const ChartWindow(10, 20));
    });

    test('zoom is limited to 4 buckets and to the full range', () {
      const full = ChartWindow.full(30);
      expect(full.zoom(30, 100, 0.5).size, 4);
      expect(const ChartWindow(10, 20).zoom(30, 0.1, 0.5), const ChartWindow(0, 30));
    });

    test('panning stays inside the data', () {
      const w = ChartWindow(10, 20);
      expect(w.pan(30, -50), const ChartWindow(0, 10));
      expect(w.pan(30, 50), const ChartWindow(20, 30));
      expect(w.pan(30, 3), const ChartWindow(13, 23));
    });

    test('ChartSeries.window slices labels and values', () {
      final s = ChartSeries(
        List.generate(10, (i) => 'L$i'),
        List.generate(10, (i) => i.toDouble()),
      ).window(3, 6);
      expect(s.labels, ['L3', 'L4', 'L5']);
      expect(s.values, [3, 4, 5]);
    });
  });

  group('StepCounterState', () {
    final morning = DateTime(2026, 11, 5, 8);

    test('counts from the first reading', () {
      var s = StepCounterState.first(10000, morning);
      s = s.apply(10500, morning.add(const Duration(hours: 1)));
      expect(s.steps, 500);
    });

    test('a restart keeps the steps already counted', () {
      var s = StepCounterState.first(10000, morning);
      s = s.apply(12000, morning.add(const Duration(hours: 2))); // 2000
      s = s.apply(300, morning.add(const Duration(hours: 3))); // rebooted
      expect(s.steps, 2300);
      s = s.apply(800, morning.add(const Duration(hours: 4)));
      expect(s.steps, 2800);
    });

    test('a new day starts from the last reading', () {
      var s = StepCounterState.first(10000, morning);
      s = s.apply(15000, DateTime(2026, 11, 5, 22));
      expect(s.steps, 5000);
      s = s.apply(15600, DateTime(2026, 11, 6, 9));
      expect(s.day, DateTime(2026, 11, 6));
      expect(s.steps, 600);
    });

    test('a restart overnight starts the new day from zero', () {
      var s = StepCounterState.first(10000, morning);
      s = s.apply(14000, DateTime(2026, 11, 5, 22));
      s = s.apply(250, DateTime(2026, 11, 6, 8));
      expect(s.steps, 250);
    });

    test('survives a JSON round trip', () {
      final s = StepCounterState.first(10, morning).apply(40, morning);
      expect(StepCounterState.fromJson(s.toJson()).steps, 30);
    });
  });

  group('StepsProvider', () {
    test('counts readings after it is turned on', () async {
      final sensor = StreamController<(int, DateTime)>();
      final steps = StepsProvider(
        sensor: () => sensor.stream,
        requestPermission: () async => true,
        supported: true,
      );
      await steps.load();
      expect(steps.isEnabled, isFalse);
      expect(await steps.enable(), isTrue);

      final now = DateTime.now();
      sensor.add((5000, now));
      sensor.add((5420, now));
      await Future<void>.delayed(Duration.zero);
      expect(steps.todaySteps, 420);
      await sensor.close();
      steps.dispose();
    });

    test('a refused permission leaves it off', () async {
      final steps = StepsProvider(
        sensor: () => const Stream.empty(),
        requestPermission: () async => false,
        supported: true,
      );
      expect(await steps.enable(), isFalse);
      expect(steps.isEnabled, isFalse);
      expect(steps.permissionDenied, isTrue);
    });

    test('unsupported devices never ask', () async {
      var asked = false;
      final steps = StepsProvider(
        sensor: () => const Stream.empty(),
        requestPermission: () async => asked = true,
        supported: false,
      );
      expect(await steps.enable(), isFalse);
      expect(asked, isFalse);
    });
  });

  group('WorkoutProvider (edit and ordering)', () {
    test('merge prefers unsynced copies and keeps date order', () {
      final loaded = [
        _w('a', DateTime(2026, 11, 5), name: 'old'),
        _w('b', DateTime(2026, 11, 3)),
      ];
      final pending = [
        _w('a', DateTime(2026, 11, 5), name: 'edited'),
        _w('c', DateTime(2026, 11, 4)),
      ];
      final merged = WorkoutProvider.merge(loaded, pending);
      expect(merged.map((w) => w.id), ['a', 'c', 'b']);
      expect(merged.first.name, 'edited');
    });

    test('update replaces the workout and can move its date (guest)', () async {
      final p = WorkoutProvider();
      final today = Formatters.dateOnly(DateTime.now());
      final w = _w(newUuid(), today);
      await p.add(w);
      await p.add(_w(newUuid(), today.subtract(const Duration(days: 1))));

      final moved = w.copyWith(
        name: 'Renamed',
        date: today.subtract(const Duration(days: 2)),
      );
      expect(await p.update(moved), isNull);
      expect(p.workouts.length, 2);
      expect(p.workouts.last.id, w.id);
      expect(p.workouts.last.name, 'Renamed');

      final reloaded = WorkoutProvider();
      await reloaded.load();
      expect(reloaded.byId(w.id)?.name, 'Renamed');
    });
  });

  group('Water (guest)', () {
    test('entries get UUIDs and survive a reload', () async {
      final water = WaterProvider();
      await water.add(250);
      await water.add(500);
      expect(water.todayMl, 750);
      expect(isLocalId(water.logs.first.id), isFalse);

      final reloaded = WaterProvider();
      await reloaded.load();
      expect(reloaded.todayMl, 750);
    });
  });

  group('ExerciseProvider (guest)', () {
    test('search puts names that start with the query first', () {
      final bench = ExerciseProvider().search('bench').map((e) => e.name).toList();
      expect(bench.first, 'Bench press');
      expect(bench, contains('Close-grip bench press'));
    });

    test('filters by muscle group', () {
      final legs = ExerciseProvider().search('', muscleGroup: 'Legs');
      expect(legs, isNotEmpty);
      expect(legs.every((e) => e.muscleGroup == 'Legs'), isTrue);
    });

    test('custom exercises are added, deduplicated and saved', () async {
      final lib = ExerciseProvider();
      final def = await lib.addCustom('  Landmine   press ', 'Shoulders');
      expect(def.name, 'Landmine press');
      expect(def.isCustom, isTrue);
      expect(() => lib.addCustom('landmine PRESS', 'Shoulders'),
          throwsArgumentError);
      expect(() => lib.addCustom('bench press', 'Chest'), throwsArgumentError);
      expect(() => lib.addCustom('   ', 'Chest'), throwsArgumentError);

      final reloaded = ExerciseProvider();
      await reloaded.load();
      expect(reloaded.find('landmine press')?.muscleGroup, 'Shoulders');

      expect(await reloaded.removeCustom(def.id!), isNull);
      expect(reloaded.find('Landmine press'), isNull);
    });
  });

  group('MeasurementProvider (guest)', () {
    test('latest values, change and chart series', () async {
      final p = MeasurementProvider();
      expect(
        await p.add(BodyMeasurement(id: newUuid(), date: DateTime(2026, 11, 1))),
        isNotNull, // empty entries are refused
      );
      await p.add(BodyMeasurement(
          id: newUuid(), date: DateTime(2026, 11, 1), weightKg: 82));
      await p.add(BodyMeasurement(
          id: newUuid(), date: DateTime(2026, 11, 3), waistCm: 90));
      await p.add(BodyMeasurement(
          id: newUuid(), date: DateTime(2026, 11, 5), weightKg: 81.2));

      final (latest, previous) = p.latestTwo((m) => m.weightKg);
      expect(latest, 81.2);
      expect(previous, 82);
      expect(p.series((m) => m.weightKg).map((e) => e.$2), [82, 81.2]);

      final reloaded = MeasurementProvider();
      await reloaded.load();
      expect(reloaded.items.length, 3);
      expect(reloaded.items.first.date, DateTime(2026, 11, 5));
    });
  });

  group('LocalStore clearing', () {
    test('clearUser removes only that account; clearGuest only guest data',
        () async {
      await LocalStore.cacheWorkouts('u1', [_w('a', DateTime(2026, 1, 1))]);
      await LocalStore.savePendingWater(
          'u1', [WaterLog(id: 'x', amountMl: 250, date: DateTime(2026, 1, 1))]);
      await LocalStore.cacheWorkouts('u2', [_w('b', DateTime(2026, 1, 1))]);
      await LocalStore.saveWorkouts([_w('g', DateTime(2026, 1, 1))]);

      expect(await LocalStore.pendingCount('u1'), 1);
      await LocalStore.clearUser('u1');
      expect(await LocalStore.loadCachedWorkouts('u1'), isEmpty);
      expect(await LocalStore.pendingCount('u1'), 0);
      expect(await LocalStore.loadCachedWorkouts('u2'), hasLength(1));
      expect(await LocalStore.loadWorkouts(), hasLength(1));

      await LocalStore.clearGuest();
      expect(await LocalStore.loadWorkouts(), isEmpty);
      expect(await LocalStore.loadCachedWorkouts('u2'), hasLength(1));
    });
  });
}
