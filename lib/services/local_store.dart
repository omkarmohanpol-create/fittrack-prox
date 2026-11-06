import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// On-device storage, in three kinds:
///
/// * Guest data (no account): the only copy of the guest's data.
/// * Offline cache (signed in): the last data loaded from Supabase, shown when
///   the device is offline. Keyed by user id.
/// * Pending writes (signed in): workouts and water saved while offline,
///   uploaded on the next successful sync. Keyed by user id.
class LocalStore {
  static const _guestWorkouts = 'guest_workouts_v1';
  static const _guestWater = 'guest_water_v1';
  static const _guestMeasurements = 'guest_measurements_v1';
  static const _guestExercises = 'guest_exercises_v1';

  static String _cache(String uid, String kind) => 'cache_${uid}_${kind}_v1';
  static String _pending(String uid, String kind) => 'pending_${uid}_${kind}_v1';

  // ------------------------------------------------------------ primitives

  static Future<List<T>> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (items.isEmpty) {
        await p.remove(key);
      } else {
        await p.setString(key, jsonEncode(items.map(toJson).toList()));
      }
    } catch (_) {
      // Best effort: the in-memory list is still correct for this session.
    }
  }

  // ------------------------------------------------------------ guest data

  static Future<List<Workout>> loadWorkouts() =>
      _loadList(_guestWorkouts, Workout.fromJson);

  static Future<void> saveWorkouts(List<Workout> workouts) =>
      _saveList(_guestWorkouts, workouts, (w) => w.toLocalJson());

  static Future<List<WaterLog>> loadWater() =>
      _loadList(_guestWater, WaterLog.fromJson);

  static Future<void> saveWater(List<WaterLog> logs) =>
      _saveList(_guestWater, logs, (l) => l.toLocalJson());

  static Future<List<BodyMeasurement>> loadMeasurements() =>
      _loadList(_guestMeasurements, BodyMeasurement.fromJson);

  static Future<void> saveMeasurements(List<BodyMeasurement> items) =>
      _saveList(_guestMeasurements, items, (m) => m.toLocalJson());

  static Future<List<ExerciseDef>> loadCustomExercises() =>
      _loadList(_guestExercises, ExerciseDef.fromJson);

  static Future<void> saveCustomExercises(List<ExerciseDef> items) =>
      _saveList(_guestExercises, items, (e) => e.toLocalJson());

  // ---------------------------------------------------------- offline cache

  static Future<List<Workout>> loadCachedWorkouts(String uid) =>
      _loadList(_cache(uid, 'workouts'), Workout.fromJson);

  static Future<void> cacheWorkouts(String uid, List<Workout> items) =>
      _saveList(_cache(uid, 'workouts'), items, (w) => w.toLocalJson());

  static Future<List<WaterLog>> loadCachedWater(String uid) =>
      _loadList(_cache(uid, 'water'), WaterLog.fromJson);

  static Future<void> cacheWater(String uid, List<WaterLog> items) =>
      _saveList(_cache(uid, 'water'), items, (l) => l.toLocalJson());

  static Future<List<BodyMeasurement>> loadCachedMeasurements(String uid) =>
      _loadList(_cache(uid, 'measurements'), BodyMeasurement.fromJson);

  static Future<void> cacheMeasurements(
          String uid, List<BodyMeasurement> items) =>
      _saveList(_cache(uid, 'measurements'), items, (m) => m.toLocalJson());

  static Future<List<ExerciseDef>> loadCachedExercises(String uid) =>
      _loadList(_cache(uid, 'exercises'), ExerciseDef.fromJson);

  static Future<void> cacheExercises(String uid, List<ExerciseDef> items) =>
      _saveList(_cache(uid, 'exercises'), items, (e) => e.toLocalJson());

  // --------------------------------------------------------- pending writes

  static Future<List<Workout>> loadPendingWorkouts(String uid) =>
      _loadList(_pending(uid, 'workouts'), Workout.fromJson);

  static Future<void> savePendingWorkouts(String uid, List<Workout> items) =>
      _saveList(_pending(uid, 'workouts'), items, (w) => w.toLocalJson());

  static Future<List<WaterLog>> loadPendingWater(String uid) =>
      _loadList(_pending(uid, 'water'), WaterLog.fromJson);

  static Future<void> savePendingWater(String uid, List<WaterLog> items) =>
      _saveList(_pending(uid, 'water'), items, (l) => l.toLocalJson());

  /// Number of unsynced workouts and water entries for [uid].
  static Future<int> pendingCount(String uid) async =>
      (await loadPendingWorkouts(uid)).length +
      (await loadPendingWater(uid)).length;

  // --------------------------------------------------------------- clearing

  /// Removes everything stored for this account on the device: cache,
  /// unsynced writes and cached goals. Used on sign-out and account deletion.
  static Future<void> clearUser(String uid) => _removeWhere(
        (k) =>
            k.startsWith('cache_${uid}_') ||
            k.startsWith('pending_${uid}_') ||
            k.startsWith('goal_${uid}_'),
      );

  /// Removes all guest data from the device.
  static Future<void> clearGuest() => _removeWhere(
        (k) => k.startsWith('guest_') || k.startsWith('goal_guest_'),
      );

  static Future<void> _removeWhere(bool Function(String key) test) async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys().where(test).toList()) {
        await p.remove(k);
      }
    } catch (_) {}
  }
}
