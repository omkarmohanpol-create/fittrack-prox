import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/step_counter.dart';
import '../services/supabase_service.dart';
import '../utils/formatters.dart';

/// Daily steps from the phone's step sensor. Off until the user turns it on
/// (it needs the physical-activity / motion permission). Steps are kept on
/// the device and, when signed in, saved to Supabase's daily_steps table.
class StepsProvider extends ChangeNotifier {
  StepsProvider({
    Stream<(int, DateTime)> Function()? sensor,
    Future<bool> Function()? requestPermission,
    bool? supported,
  })  : _sensor = sensor ?? _pedometer,
        _requestPermission = requestPermission ?? _askPermission,
        _supported = supported ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS));

  static const _enabledKey = 'steps_enabled_v1';
  static const _stateKey = 'steps_state_v1';
  static const _historyKey = 'steps_history_v1';
  static const _keepDays = 60;

  final Stream<(int, DateTime)> Function() _sensor;
  final Future<bool> Function() _requestPermission;
  final bool _supported;

  bool _enabled = false;
  bool _denied = false;
  bool _unavailable = false;
  StepCounterState? _state;
  Map<DateTime, int> _history = {};
  StreamSubscription<(int, DateTime)>? _sub;
  DateTime? _lastSave;
  DateTime? _lastUpload;

  bool get isSupported => _supported && !_unavailable;
  bool get isEnabled => _enabled;

  /// The user refused the permission the last time it was asked for.
  bool get permissionDenied => _denied;

  int stepsOn(DateTime day) => _history[Formatters.dateOnly(day)] ?? 0;
  int get todaySteps => stepsOn(DateTime.now());

  /// Steps for the last [days] days, oldest first.
  List<int> lastDays(int days) {
    final today = Formatters.dateOnly(DateTime.now());
    return List.generate(
      days,
      (i) => stepsOn(today.subtract(Duration(days: days - 1 - i))),
    );
  }

  static Stream<(int, DateTime)> _pedometer() =>
      Pedometer.stepCountStream.map((e) => (e.steps, e.timeStamp));

  static Future<bool> _askPermission() async {
    final permission = defaultTargetPlatform == TargetPlatform.iOS
        ? Permission.sensors
        : Permission.activityRecognition;
    final status = await permission.request();
    return status.isGranted || status.isLimited;
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _enabled = p.getBool(_enabledKey) ?? false;
      final rawState = p.getString(_stateKey);
      if (rawState != null) {
        _state = StepCounterState.fromJson(
          jsonDecode(rawState) as Map<String, dynamic>,
        );
      }
      final rawHistory = p.getString(_historyKey);
      if (rawHistory != null) {
        _history = {
          for (final e in (jsonDecode(rawHistory) as Map<String, dynamic>).entries)
            DateTime.parse(e.key): (e.value as num).toInt(),
        };
      }
    } catch (_) {}

    if (SupabaseService.canSync) {
      try {
        final remote = await SupabaseService.fetchSteps(
          since: DateTime.now().subtract(const Duration(days: 30)),
        );
        // Another phone may have counted more on the same day.
        remote.forEach((day, steps) {
          if (steps > (_history[day] ?? 0)) _history[day] = steps;
        });
      } catch (_) {}
    }

    if (_enabled && isSupported) _start();
    notifyListeners();
  }

  /// Asks for the permission and starts counting. Returns false if the
  /// permission was refused or the phone has no step sensor.
  Future<bool> enable() async {
    if (!isSupported) return false;
    final granted = await _requestPermission();
    _denied = !granted;
    if (!granted) {
      notifyListeners();
      return false;
    }
    _enabled = true;
    await _saveEnabled();
    _start();
    notifyListeners();
    return true;
  }

  Future<void> disable() async {
    await _sub?.cancel();
    _sub = null;
    _enabled = false;
    await _saveEnabled();
    notifyListeners();
  }

  void _start() {
    _sub ??= _sensor().listen(
      (r) => onReading(r.$1, r.$2),
      onError: (Object _) {
        // No step sensor, or the permission was revoked in system settings.
        _unavailable = true;
        _sub?.cancel();
        _sub = null;
        notifyListeners();
      },
    );
  }

  /// Applies one sensor reading. Public for tests.
  @visibleForTesting
  void onReading(int total, DateTime at) {
    final before = _state;
    final next = before == null
        ? StepCounterState.first(total, at)
        : before.apply(total, at);
    _state = next;
    _history[next.day] = next.steps;

    final cutoff = Formatters.dateOnly(at).subtract(const Duration(days: _keepDays));
    _history.removeWhere((day, _) => day.isBefore(cutoff));
    notifyListeners();

    final now = DateTime.now();
    if (before != null && next.day != before.day) {
      // Day changed: store yesterday's final count straight away.
      unawaited(_upload(before.day, before.steps));
      unawaited(_save());
    } else {
      if (_lastSave == null || now.difference(_lastSave!).inSeconds >= 15) {
        unawaited(_save());
      }
      if (_lastUpload == null || now.difference(_lastUpload!).inMinutes >= 2) {
        unawaited(_upload(next.day, next.steps));
      }
    }
  }

  /// Saves and uploads right away (called when the app goes to background).
  Future<void> flush() async {
    final s = _state;
    if (s == null) return;
    await _save();
    await _upload(s.day, s.steps);
  }

  Future<void> _upload(DateTime day, int steps) async {
    if (!SupabaseService.canSync) return;
    _lastUpload = DateTime.now();
    try {
      await SupabaseService.upsertSteps(day, steps);
    } catch (_) {
      // Tried again on the next reading after two minutes.
    }
  }

  Future<void> _save() async {
    _lastSave = DateTime.now();
    try {
      final p = await SharedPreferences.getInstance();
      final s = _state;
      if (s != null) await p.setString(_stateKey, jsonEncode(s.toJson()));
      await p.setString(
        _historyKey,
        jsonEncode({
          for (final e in _history.entries) Formatters.isoDate(e.key): e.value,
        }),
      );
    } catch (_) {}
  }

  Future<void> _saveEnabled() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_enabledKey, _enabled);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
