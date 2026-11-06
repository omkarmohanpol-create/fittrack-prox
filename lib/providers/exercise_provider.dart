import 'package:flutter/foundation.dart';

import '../data/exercise_library.dart';
import '../models/models.dart';
import '../services/local_store.dart';
import '../services/supabase_service.dart';
import '../services/sync_errors.dart';

/// Built-in exercises plus the user's own. Custom exercises sync to Supabase
/// for signed-in users and stay on the device for guests.
class ExerciseProvider extends ChangeNotifier {
  List<ExerciseDef> _custom = [];

  List<ExerciseDef> get custom => List.unmodifiable(_custom);

  /// Every exercise, sorted by name. A custom exercise with the same name as
  /// a built-in one (any case) is not possible: [addCustom] refuses it.
  List<ExerciseDef> get all {
    final list = [...builtInExercises, ..._custom];
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Exercises whose name contains [query] (any case), optionally limited to
  /// one muscle group. Names that start with the query come first.
  List<ExerciseDef> search(String query, {String? muscleGroup}) {
    final q = query.trim().toLowerCase();
    final matches = all.where((e) {
      if (muscleGroup != null && e.muscleGroup != muscleGroup) return false;
      return q.isEmpty || e.name.toLowerCase().contains(q);
    }).toList();
    if (q.isEmpty) return matches;
    final starts = matches.where((e) => e.name.toLowerCase().startsWith(q));
    final rest = matches.where((e) => !e.name.toLowerCase().startsWith(q));
    return [...starts, ...rest];
  }

  ExerciseDef? find(String name) {
    final n = name.trim().toLowerCase();
    for (final e in all) {
      if (e.name.toLowerCase() == n) return e;
    }
    return null;
  }

  Future<void> load() async {
    final uid = SupabaseService.userId;
    if (uid == null) {
      _custom = await LocalStore.loadCustomExercises();
      notifyListeners();
      return;
    }
    try {
      _custom = await SupabaseService.fetchCustomExercises();
      await LocalStore.cacheExercises(uid, _custom);
    } catch (_) {
      _custom = await LocalStore.loadCachedExercises(uid);
    }
    notifyListeners();
  }

  /// Returns the new exercise, or throws an [ArgumentError] / [StateError]
  /// with a message for the user.
  Future<ExerciseDef> addCustom(String name, String muscleGroup) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) throw ArgumentError('Enter a name');
    if (clean.length > 80) throw ArgumentError('Use at most 80 characters');
    if (find(clean) != null) {
      throw ArgumentError('"$clean" is already in the library');
    }
    final def = ExerciseDef(clean, muscleGroup, id: newUuid());
    final uid = SupabaseService.userId;
    if (uid != null) {
      try {
        await SupabaseService.insertCustomExercise(def);
      } catch (e) {
        throw StateError(isServerRejection(e)
            ? 'Could not add the exercise.'
            : 'Adding exercises needs a connection.');
      }
    }
    _custom = [..._custom, def];
    notifyListeners();
    await _persist(uid);
    return def;
  }

  /// Returns null on success, or an error message.
  Future<String?> removeCustom(String id) async {
    final uid = SupabaseService.userId;
    if (uid != null) {
      try {
        await SupabaseService.deleteCustomExercise(id);
      } catch (_) {
        return 'Could not delete the exercise. Check your connection.';
      }
    }
    _custom = _custom.where((e) => e.id != id).toList();
    notifyListeners();
    await _persist(uid);
    return null;
  }

  Future<void> _persist(String? uid) => uid == null
      ? LocalStore.saveCustomExercises(_custom)
      : LocalStore.cacheExercises(uid, _custom);

  void clear() {
    _custom = [];
    notifyListeners();
  }
}
