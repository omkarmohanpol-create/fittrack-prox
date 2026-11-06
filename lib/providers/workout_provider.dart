import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/local_store.dart';
import '../services/supabase_service.dart';
import '../services/sync_errors.dart';
import '../utils/formatters.dart';

class WorkoutProvider extends ChangeNotifier {
  /// How far back workouts are loaded (matches AppConstants.maxBackdateDays).
  static const window = Duration(days: 366);

  List<Workout> _workouts = [];
  Set<String> _pendingIds = {};
  bool _loading = false;
  bool _offline = false;
  String? _error;

  List<Workout> get workouts => List.unmodifiable(_workouts);
  bool get isLoading => _loading;
  String? get error => _error;

  /// True when the last load could not reach Supabase and saved data is shown.
  bool get isOffline => _offline;

  /// True for a workout saved on the device that has not reached Supabase yet.
  bool isPending(String id) => _pendingIds.contains(id);
  int get pendingCount => _pendingIds.length;

  /// Newest first; workouts on the same day keep their relative order.
  static List<Workout> sortByDate(Iterable<Workout> items) {
    final indexed = items.toList().asMap().entries.toList();
    indexed.sort((a, b) {
      final byDate = b.value.date.compareTo(a.value.date);
      return byDate != 0 ? byDate : a.key.compareTo(b.key);
    });
    return [for (final e in indexed) e.value];
  }

  /// Saved-but-unsynced copies replace the loaded ones with the same id.
  static List<Workout> merge(List<Workout> loaded, List<Workout> pending) {
    final ids = pending.map((w) => w.id).toSet();
    return sortByDate([...pending, ...loaded.where((w) => !ids.contains(w.id))]);
  }

  /// Signed-in users read from Supabase (falling back to the offline cache);
  /// guests read what is saved on the device.
  Future<void> load() async {
    final uid = SupabaseService.userId;
    if (uid == null) {
      _workouts = sortByDate(await LocalStore.loadWorkouts());
      _pendingIds = {};
      _offline = false;
      _error = null;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    final pending = await _flush(uid, await LocalStore.loadPendingWorkouts(uid));
    try {
      final remote = await SupabaseService.fetchWorkouts(
        since: DateTime.now().subtract(window),
      );
      _offline = false;
      _workouts = merge(remote, pending);
      await LocalStore.cacheWorkouts(uid, remote);
    } catch (_) {
      _offline = true;
      final cached = await LocalStore.loadCachedWorkouts(uid);
      _workouts = merge(cached, pending);
      if (_workouts.isEmpty) _error = 'Could not load workouts. Pull to retry.';
    }
    _pendingIds = pending.map((w) => w.id).toSet();
    _loading = false;
    notifyListeners();
  }

  /// Uploads saved-offline workouts. Returns the ones that are still waiting.
  Future<List<Workout>> _flush(String uid, List<Workout> pending) async {
    if (pending.isEmpty) return pending;
    final left = <Workout>[];
    for (final w in pending) {
      try {
        await SupabaseService.saveWorkout(w);
      } catch (_) {
        left.add(w);
      }
    }
    if (left.length != pending.length) {
      await LocalStore.savePendingWorkouts(uid, left);
    }
    return left;
  }

  /// Tries to upload saved-offline workouts again (called when the app
  /// comes back to the foreground).
  Future<void> syncPending() async {
    final uid = SupabaseService.userId;
    if (uid == null || _pendingIds.isEmpty) return;
    final left = await _flush(uid, await LocalStore.loadPendingWorkouts(uid));
    final ids = left.map((w) => w.id).toSet();
    if (ids.length != _pendingIds.length) {
      _pendingIds = ids;
      if (ids.isEmpty) _offline = false;
      notifyListeners();
    }
  }

  /// Adds a new workout. Returns null on success, or an error message.
  /// Offline, the workout is kept on the device and uploaded later; check
  /// [isPending] to tell the user.
  Future<String?> add(Workout w) => _save(w);

  /// Saves changes to an existing workout (matched by id).
  Future<String?> update(Workout w) => _save(w);

  Future<String?> _save(Workout input) async {
    final uid = SupabaseService.userId;
    // Signed-in rows need a real UUID; old guest ids look like "local-...".
    final w = uid != null && isLocalId(input.id)
        ? input.copyWith(id: newUuid())
        : input;

    if (uid != null) {
      try {
        await SupabaseService.saveWorkout(w);
        if (_pendingIds.remove(w.id)) {
          await _writePending(uid, (list) => list.where((x) => x.id != w.id));
        }
      } catch (e) {
        if (isServerRejection(e)) {
          return 'Could not save the workout. Please try again.';
        }
        _pendingIds.add(w.id);
        await _writePending(uid, (list) => [w, ...list.where((x) => x.id != w.id)]);
      }
    }

    _workouts = sortByDate([w, ..._workouts.where((x) => x.id != w.id)]);
    notifyListeners();
    await _persist(uid);
    return null;
  }

  /// Returns null on success, or an error message. A synced workout is only
  /// removed once Supabase confirms the delete.
  Future<String?> remove(String id) async {
    final uid = SupabaseService.userId;
    if (uid != null) {
      if (_pendingIds.remove(id)) {
        await _writePending(uid, (list) => list.where((x) => x.id != id));
        // It may have reached the server before the connection dropped.
        try {
          await SupabaseService.deleteWorkout(id);
        } catch (_) {}
      } else if (!isLocalId(id)) {
        try {
          await SupabaseService.deleteWorkout(id);
        } catch (_) {
          return 'Could not delete the workout. Check your connection.';
        }
      }
    }
    _workouts = _workouts.where((w) => w.id != id).toList();
    notifyListeners();
    await _persist(uid);
    return null;
  }

  Future<void> _writePending(
    String uid,
    Iterable<Workout> Function(List<Workout>) change,
  ) async {
    final list = await LocalStore.loadPendingWorkouts(uid);
    await LocalStore.savePendingWorkouts(uid, change(list).toList());
  }

  Future<void> _persist(String? uid) async {
    if (uid == null) {
      await LocalStore.saveWorkouts(_workouts);
    } else {
      await LocalStore.cacheWorkouts(
        uid,
        _workouts.where((w) => !_pendingIds.contains(w.id)).toList(),
      );
    }
  }

  /// Clears what is on screen. Saved data on the device is kept.
  void clear() {
    _workouts = [];
    _pendingIds = {};
    _offline = false;
    _error = null;
    notifyListeners();
  }

  // --------------------------------------------------------------- derived

  Workout? byId(String id) {
    for (final w in _workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  List<Workout> forDay(DateTime day) {
    final d = Formatters.dateOnly(day);
    return _workouts
        .where((w) => Formatters.dateOnly(w.date) == d)
        .toList(growable: false);
  }

  bool hasWorkoutOn(DateTime day) => forDay(day).isNotEmpty;

  int workoutsInLastDays(int days) {
    final today = Formatters.dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    return _workouts
        .where((w) => !Formatters.dateOnly(w.date).isBefore(start))
        .length;
  }

  int get caloriesToday =>
      forDay(DateTime.now()).fold(0, (s, w) => s + w.caloriesBurned);

  int get minutesToday =>
      forDay(DateTime.now()).fold(0, (s, w) => s + w.durationMinutes);

  /// Consecutive days with a workout, ending today (or yesterday if nothing
  /// has been logged yet today, so the streak is not lost mid-day).
  int get currentStreak {
    final days = _workouts.map((w) => Formatters.dateOnly(w.date)).toSet();
    var cursor = Formatters.dateOnly(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get totalWorkouts => _workouts.length;
}
