import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class GoalProvider extends ChangeNotifier {
  final Map<String, Goal> _goals = {};

  /// Cached goals are keyed per user ('guest' when not signed in).
  String _key(String type) => 'goal_${SupabaseService.userId ?? 'guest'}_$type';

  int get workoutsPerWeekGoal =>
      _goals[GoalType.workoutsPerWeek]?.targetValue ??
      AppConstants.defaultWorkoutsPerWeek;

  int get waterGoalMl =>
      _goals[GoalType.waterDaily]?.targetValue ??
      AppConstants.defaultWaterGoalMl;

  int get stepsGoal =>
      _goals[GoalType.stepsDaily]?.targetValue ?? AppConstants.defaultStepsGoal;

  Future<void> load() async {
    // Local values first (also the only source in guest mode).
    try {
      final p = await SharedPreferences.getInstance();
      for (final type in const [
        GoalType.workoutsPerWeek,
        GoalType.waterDaily,
        GoalType.stepsDaily,
      ]) {
        final v = p.getInt(_key(type));
        if (v != null) _goals[type] = _make(type, v);
      }
    } catch (_) {}

    if (SupabaseService.canSync) {
      try {
        for (final g in await SupabaseService.fetchGoals()) {
          _goals[g.goalType] = g;
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Goal _make(String type, int value) => Goal(
        goalType: type,
        targetValue: value,
        period: type == GoalType.workoutsPerWeek ? 'weekly' : 'daily',
      );

  Future<void> setGoal(String type, int value) async {
    final goal = _make(type, value);
    _goals[type] = goal;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_key(type), value);
    } catch (_) {}
    if (SupabaseService.canSync) {
      try {
        await SupabaseService.upsertGoal(goal);
      } catch (_) {}
    }
  }

  void clear() {
    _goals.clear();
    notifyListeners();
  }
}
