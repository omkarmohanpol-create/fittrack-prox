import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool _useMetric = true;
  bool _workoutReminder = false;
  bool _waterReminder = false;
  TimeOfDay _workoutTime = const TimeOfDay(hour: 18, minute: 0);

  bool get useMetric => _useMetric;
  bool get workoutReminder => _workoutReminder;
  bool get waterReminder => _waterReminder;
  TimeOfDay get workoutTime => _workoutTime;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _useMetric = p.getBool('use_metric') ?? true;
      _workoutReminder = p.getBool('workout_reminder') ?? false;
      _waterReminder = p.getBool('water_reminder') ?? false;
      _workoutTime = TimeOfDay(
        hour: p.getInt('workout_hour') ?? 18,
        minute: p.getInt('workout_minute') ?? 0,
      );
      notifyListeners();
      // Re-arm reminders in case the OS dropped them.
      if (_workoutReminder) {
        await NotificationService.instance.scheduleWorkoutReminder(_workoutTime);
      }
      if (_waterReminder) {
        await NotificationService.instance.scheduleWaterReminders();
      }
    } catch (_) {}
  }

  Future<void> _save(Future<void> Function(SharedPreferences p) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  Future<void> setMetric(bool value) async {
    _useMetric = value;
    notifyListeners();
    await _save((p) => p.setBool('use_metric', value));
  }

  Future<void> setWorkoutReminder(bool value) async {
    _workoutReminder = value;
    notifyListeners();
    if (value) {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.scheduleWorkoutReminder(_workoutTime);
    } else {
      await NotificationService.instance.cancelWorkoutReminder();
    }
    await _save((p) => p.setBool('workout_reminder', value));
  }

  Future<void> setWorkoutTime(TimeOfDay time) async {
    _workoutTime = time;
    notifyListeners();
    if (_workoutReminder) {
      await NotificationService.instance.scheduleWorkoutReminder(time);
    }
    await _save((p) async {
      await p.setInt('workout_hour', time.hour);
      await p.setInt('workout_minute', time.minute);
    });
  }

  Future<void> setWaterReminder(bool value) async {
    _waterReminder = value;
    notifyListeners();
    if (value) {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.scheduleWaterReminders();
    } else {
      await NotificationService.instance.cancelWaterReminders();
    }
    await _save((p) => p.setBool('water_reminder', value));
  }
}
