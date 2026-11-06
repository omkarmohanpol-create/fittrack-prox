import 'dart:math';

import '../utils/formatters.dart';

String newLocalId() => 'local-${DateTime.now().microsecondsSinceEpoch}';

bool isLocalId(String id) => id.startsWith('local-');

final Random _random = Random.secure();

/// Random (version 4) UUID. Signed-in rows get their id on the device, so a
/// save that is retried after a lost connection updates the same row instead
/// of creating a duplicate.
String newUuid() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b
      .sublist(from, to)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

class WorkoutExercise {
  final String name;
  final String? muscleGroup;
  final int sets;
  final int reps;
  final double weightKg;
  final int durationSeconds;

  const WorkoutExercise({
    required this.name,
    this.muscleGroup,
    this.sets = 0,
    this.reps = 0,
    this.weightKg = 0,
    this.durationSeconds = 0,
  });

  /// Total weight moved (sets x reps x kg).
  double get volume => sets * reps * weightKg;

  Map<String, dynamic> toInsertJson(String workoutId, int index) => {
        'workout_id': workoutId,
        'exercise_name': name,
        'muscle_group': muscleGroup,
        'sets': sets,
        'reps': reps,
        'weight_kg': weightKg,
        'duration_seconds': durationSeconds,
        'order_index': index,
      };

  Map<String, dynamic> toLocalJson() => {
        'exercise_name': name,
        'muscle_group': muscleGroup,
        'sets': sets,
        'reps': reps,
        'weight_kg': weightKg,
        'duration_seconds': durationSeconds,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> j) => WorkoutExercise(
        name: j['exercise_name'] as String,
        muscleGroup: j['muscle_group'] as String?,
        sets: (j['sets'] as num?)?.toInt() ?? 0,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        weightKg: (j['weight_kg'] as num?)?.toDouble() ?? 0,
        durationSeconds: (j['duration_seconds'] as num?)?.toInt() ?? 0,
      );
}

class Workout {
  final String id;
  final String type; // 'strength' | 'cardio'
  final String name;
  final DateTime date;
  final int durationMinutes;
  final int caloriesBurned;
  final String? notes;
  final List<WorkoutExercise> exercises;

  const Workout({
    required this.id,
    required this.type,
    required this.name,
    required this.date,
    this.durationMinutes = 0,
    this.caloriesBurned = 0,
    this.notes,
    this.exercises = const [],
  });

  bool get isCardio => type == 'cardio';

  double get volume => exercises.fold(0.0, (sum, e) => sum + e.volume);

  Workout copyWith({
    String? id,
    String? type,
    String? name,
    DateTime? date,
    int? durationMinutes,
    int? caloriesBurned,
    String? notes,
    List<WorkoutExercise>? exercises,
  }) =>
      Workout(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        date: date ?? this.date,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        caloriesBurned: caloriesBurned ?? this.caloriesBurned,
        notes: notes ?? this.notes,
        exercises: exercises ?? this.exercises,
      );

  /// Parameters for the `save_workout` database function (supabase/schema.sql),
  /// which inserts or updates the workout and replaces its exercises in one
  /// transaction.
  Map<String, dynamic> toSaveParams() => {
        'p_workout': {
          'id': id,
          'type': type,
          'name': name,
          'date': Formatters.isoDate(date),
          'duration_minutes': durationMinutes,
          'calories_burned': caloriesBurned,
          'notes': notes,
        },
        'p_exercises': [
          for (var i = 0; i < exercises.length; i++)
            {...exercises[i].toLocalJson(), 'order_index': i},
        ],
      };

  Map<String, dynamic> toInsertJson(String userId) => {
        'user_id': userId,
        'type': type,
        'name': name,
        'date': Formatters.isoDate(date),
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'notes': notes,
      };

  /// Same shape as a Supabase row, so [Workout.fromJson] reads it back.
  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'type': type,
        'name': name,
        'date': Formatters.isoDate(date),
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'notes': notes,
        'workout_exercises': exercises.map((e) => e.toLocalJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> j) {
    final rawExercises = (j['workout_exercises'] as List?) ?? const [];
    final exercises = rawExercises
        .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
        .toList();
    return Workout(
      id: j['id'] as String,
      type: (j['type'] as String?) ?? 'strength',
      name: j['name'] as String,
      date: DateTime.parse(j['date'] as String),
      durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
      caloriesBurned: (j['calories_burned'] as num?)?.toInt() ?? 0,
      notes: j['notes'] as String?,
      exercises: exercises,
    );
  }
}

class WaterLog {
  final String id;
  final int amountMl;
  final DateTime date;

  const WaterLog({
    required this.id,
    required this.amountMl,
    required this.date,
  });

  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'amount_ml': amountMl,
        'date': Formatters.isoDate(date),
      };

  factory WaterLog.fromJson(Map<String, dynamic> j) => WaterLog(
        id: j['id'] as String,
        amountMl: (j['amount_ml'] as num).toInt(),
        date: DateTime.parse(j['date'] as String),
      );
}

/// One body-measurement check-in. Weight is stored in kg and lengths in cm;
/// any field can be left empty.
class BodyMeasurement {
  final String id;
  final DateTime date;
  final double? weightKg;
  final double? bodyFatPct;
  final double? waistCm;
  final double? chestCm;
  final double? armCm;
  final double? hipsCm;
  final String? notes;

  const BodyMeasurement({
    required this.id,
    required this.date,
    this.weightKg,
    this.bodyFatPct,
    this.waistCm,
    this.chestCm,
    this.armCm,
    this.hipsCm,
    this.notes,
  });

  bool get isEmpty =>
      weightKg == null &&
      bodyFatPct == null &&
      waistCm == null &&
      chestCm == null &&
      armCm == null &&
      hipsCm == null;

  static double? _num(Object? v) => (v as num?)?.toDouble();

  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'date': Formatters.isoDate(date),
        'weight_kg': weightKg,
        'body_fat_pct': bodyFatPct,
        'waist_cm': waistCm,
        'chest_cm': chestCm,
        'arm_cm': armCm,
        'hips_cm': hipsCm,
        'notes': notes,
      };

  Map<String, dynamic> toInsertJson(String userId) =>
      {...toLocalJson(), 'user_id': userId};

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        weightKg: _num(j['weight_kg']),
        bodyFatPct: _num(j['body_fat_pct']),
        waistCm: _num(j['waist_cm']),
        chestCm: _num(j['chest_cm']),
        armCm: _num(j['arm_cm']),
        hipsCm: _num(j['hips_cm']),
        notes: j['notes'] as String?,
      );
}

/// An exercise in the library: built in, or added by the user.
class ExerciseDef {
  final String? id; // null for built-in exercises
  final String name;
  final String muscleGroup;

  const ExerciseDef(this.name, this.muscleGroup, {this.id});

  bool get isCustom => id != null;

  Map<String, dynamic> toLocalJson() =>
      {'id': id, 'name': name, 'muscle_group': muscleGroup};

  factory ExerciseDef.fromJson(Map<String, dynamic> j) => ExerciseDef(
        j['name'] as String,
        (j['muscle_group'] as String?) ?? 'Full body',
        id: j['id'] as String,
      );
}

class Goal {
  final String goalType;
  final int targetValue;
  final String period; // 'daily' | 'weekly'
  final bool isActive;

  const Goal({
    required this.goalType,
    required this.targetValue,
    required this.period,
    this.isActive = true,
  });

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        goalType: j['goal_type'] as String,
        targetValue: (j['target_value'] as num).toInt(),
        period: (j['period'] as String?) ?? 'daily',
        isActive: (j['is_active'] as bool?) ?? true,
      );
}
