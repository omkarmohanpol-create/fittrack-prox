import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/gradient_button.dart';

/// Stopwatch for the whole workout plus a rest countdown between sets.
/// "Finish" closes the screen and returns the elapsed time, which the caller
/// passes to the log sheet as the workout's minutes.
///
/// Both clocks are worked out from timestamps, not by counting ticks, so they
/// stay right if the phone locks or the app goes to the background.
class WorkoutTimerScreen extends StatefulWidget {
  const WorkoutTimerScreen({super.key});

  @override
  State<WorkoutTimerScreen> createState() => _WorkoutTimerScreenState();
}

class _WorkoutTimerScreenState extends State<WorkoutTimerScreen> {
  Duration _banked = Duration.zero; // elapsed before the current run
  DateTime? _runningSince;
  DateTime? _restEndsAt;
  int _restTotal = 0;
  bool _restAlerted = false;
  Timer? _ticker;

  bool get _running => _runningSince != null;

  Duration get _elapsed => _running
      ? _banked + DateTime.now().difference(_runningSince!)
      : _banked;

  Duration get _restLeft {
    final end = _restEndsAt;
    if (end == null) return Duration.zero;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    if (_restEndsAt != null && !_restAlerted && _restLeft == Duration.zero) {
      _restAlerted = true;
      _alert();
    }
    setState(() {});
  }

  Future<void> _alert() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await HapticFeedback.heavyImpact();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_running) {
        _banked += DateTime.now().difference(_runningSince!);
        _runningSince = null;
      } else {
        _runningSince = DateTime.now();
      }
    });
  }

  void _reset() {
    setState(() {
      _banked = Duration.zero;
      _runningSince = _running ? DateTime.now() : null;
    });
  }

  void _startRest(int seconds) {
    HapticFeedback.selectionClick();
    setState(() {
      _restTotal = seconds;
      _restEndsAt = DateTime.now().add(Duration(seconds: seconds));
      _restAlerted = false;
      // Resting is part of the workout.
      _runningSince ??= DateTime.now();
    });
  }

  void _addRest(int seconds) {
    final end = _restEndsAt;
    if (end == null) return;
    setState(() {
      final base = end.isBefore(DateTime.now()) ? DateTime.now() : end;
      _restEndsAt = base.add(Duration(seconds: seconds));
      _restTotal += seconds;
      _restAlerted = false;
    });
  }

  void _stopRest() => setState(() => _restEndsAt = null);

  Future<bool> _confirmLeave() async {
    if (_elapsed < const Duration(seconds: 5)) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this timer?'),
        content: const Text('The time will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep timing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _elapsed;
    final restLeft = _restLeft;
    final resting = _restEndsAt != null;
    final restDone = resting && restLeft == Duration.zero;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Workout timer')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: Text(
                Formatters.clock(elapsed),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Center(
              child: Text(
                _running ? 'Workout in progress' : 'Paused',
                style: TextStyle(color: context.muted),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: elapsed == Duration.zero ? null : _reset,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(_running
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    label: Text(_running
                        ? 'Pause'
                        : (elapsed == Duration.zero ? 'Start' : 'Resume')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Rest timer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: restDone ? AppColors.steps : context.borderColor,
                  width: restDone ? 2 : 1,
                ),
              ),
              child: resting
                  ? Column(
                      children: [
                        Text(
                          restDone ? 'Rest over. Next set!' : 'Resting',
                          style: TextStyle(
                            color: restDone ? AppColors.steps : context.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Formatters.clock(restLeft),
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _restTotal == 0
                              ? 0
                              : 1 - restLeft.inMilliseconds / (_restTotal * 1000),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => _addRest(15),
                              child: const Text('+15 s'),
                            ),
                            TextButton(
                              onPressed: _stopRest,
                              child: Text(restDone ? 'Done' : 'Skip'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in AppConstants.restPresets)
                          ActionChip(
                            label: Text(Formatters.clock(Duration(seconds: s))),
                            onPressed: () => _startRest(s),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Finish and log workout',
              icon: Icons.check_rounded,
              onPressed: elapsed == Duration.zero
                  ? null
                  : () => Navigator.of(context).pop(elapsed),
            ),
          ],
        ),
      ),
    );
  }
}
