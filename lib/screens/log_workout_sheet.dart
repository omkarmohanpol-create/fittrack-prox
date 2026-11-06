import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/gradient_button.dart';
import 'exercise_picker_sheet.dart';

/// Opens the sheet to log a new workout, or to edit [workout] when given.
/// [minutes] pre-fills the duration (used by the workout timer).
Future<void> showLogWorkoutSheet(
  BuildContext context, {
  Workout? workout,
  int? minutes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => LogWorkoutSheet(workout: workout, minutes: minutes),
  );
}

class _ExerciseRow {
  final name = TextEditingController();
  final sets = TextEditingController();
  final reps = TextEditingController();
  final weight = TextEditingController();
  String? muscle;

  _ExerciseRow();

  _ExerciseRow.from(WorkoutExercise e, bool metric) {
    name.text = e.name;
    muscle = AppConstants.muscleGroups.contains(e.muscleGroup)
        ? e.muscleGroup
        : null;
    if (e.sets > 0) sets.text = '${e.sets}';
    if (e.reps > 0) reps.text = '${e.reps}';
    if (e.weightKg > 0) {
      final v = Formatters.kgToDisplay(e.weightKg, metric);
      weight.text = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(1);
    }
  }

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
  }
}

class LogWorkoutSheet extends StatefulWidget {
  final Workout? workout;
  final int? minutes;

  const LogWorkoutSheet({super.key, this.workout, this.minutes});

  @override
  State<LogWorkoutSheet> createState() => _LogWorkoutSheetState();
}

class _LogWorkoutSheetState extends State<LogWorkoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _duration = TextEditingController();
  final _calories = TextEditingController();
  final _notes = TextEditingController();
  final List<_ExerciseRow> _rows = [];
  String _type = 'strength';
  DateTime _date = Formatters.dateOnly(DateTime.now());
  bool _saving = false;

  bool get _editing => widget.workout != null;

  @override
  void initState() {
    super.initState();
    final w = widget.workout;
    if (w != null) {
      final metric = context.read<SettingsProvider>().useMetric;
      _type = w.type;
      _date = Formatters.dateOnly(w.date);
      _name.text = w.name;
      if (w.durationMinutes > 0) _duration.text = '${w.durationMinutes}';
      if (w.caloriesBurned > 0) _calories.text = '${w.caloriesBurned}';
      _notes.text = w.notes ?? '';
      _rows.addAll(w.exercises.map((e) => _ExerciseRow.from(e, metric)));
    }
    final minutes = widget.minutes;
    if (minutes != null && minutes > 0) _duration.text = '$minutes';
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _calories.dispose();
    _notes.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = Formatters.dateOnly(DateTime.now());
    final first =
        today.subtract(const Duration(days: AppConstants.maxBackdateDays));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today)
          ? today
          : (_date.isBefore(first) ? first : _date),
      firstDate: first,
      lastDate: today,
      helpText: 'Workout date',
    );
    if (picked != null && mounted) {
      setState(() => _date = Formatters.dateOnly(picked));
    }
  }

  Future<void> _pickExercise(_ExerciseRow row) async {
    final picked = await showExercisePicker(context, initialQuery: row.name.text);
    if (picked == null || !mounted) return;
    setState(() {
      row.name.text = picked.name;
      row.muscle = picked.muscleGroup;
    });
  }

  Future<void> _addExercise() async {
    final picked = await showExercisePicker(context);
    if (!mounted) return;
    setState(() {
      final row = _ExerciseRow();
      if (picked != null) {
        row.name.text = picked.name;
        row.muscle = picked.muscleGroup;
      }
      _rows.add(row);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final metric = context.read<SettingsProvider>().useMetric;
    final provider = context.read<WorkoutProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final exercises = <WorkoutExercise>[
      if (_type == 'strength')
        for (final r in _rows)
          if (r.name.text.trim().isNotEmpty)
            WorkoutExercise(
              name: r.name.text.trim(),
              muscleGroup: r.muscle,
              sets: int.tryParse(r.sets.text.trim()) ?? 0,
              reps: int.tryParse(r.reps.text.trim()) ?? 0,
              weightKg: Formatters.displayToKg(
                double.tryParse(r.weight.text.trim()) ?? 0,
                metric,
              ),
            ),
    ];

    final workout = Workout(
      id: widget.workout?.id ?? newUuid(),
      type: _type,
      name: _name.text.trim(),
      date: _date,
      durationMinutes: int.tryParse(_duration.text.trim()) ?? 0,
      caloriesBurned: int.tryParse(_calories.text.trim()) ?? 0,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      exercises: exercises,
    );

    final error = _editing
        ? await provider.update(workout)
        : await provider.add(workout);
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();

    final saved = provider.workouts
        .where((w) => w.name == workout.name && w.date == workout.date)
        .firstOrNull;
    final offline = saved != null && provider.isPending(saved.id);
    final day = Formatters.relativeDay(workout.date);
    final what = _editing ? 'Workout updated' : 'Workout logged';
    final text = offline
        ? '$what on this phone. It will sync when you are back online.'
        : (day == 'Today' || _editing ? what : '$what for $day');
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final metric = context.watch<SettingsProvider>().useMetric;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        bottomInset + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _editing ? 'Edit workout' : 'Log workout',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'strength',
                  label: Text('Strength'),
                  icon: Icon(Icons.fitness_center_rounded),
                ),
                ButtonSegment(
                  value: 'cardio',
                  label: Text('Cardio'),
                  icon: Icon(Icons.directions_run_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                  suffixIcon: Icon(Icons.expand_more_rounded),
                ),
                child: Text(Formatters.relativeDay(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: _type == 'cardio' ? 'Morning run' : 'Push day',
              ),
              validator: (v) => Validators.required(v, 'Name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                    validator: Validators.optionalInt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _calories,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Calories'),
                    validator: Validators.optionalInt,
                  ),
                ),
              ],
            ),
            if (_type == 'strength') ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Exercises',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _addExercise,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ],
              ),
              for (var i = 0; i < _rows.length; i++)
                _ExerciseEditor(
                  key: ObjectKey(_rows[i]),
                  row: _rows[i],
                  weightUnit: metric ? 'kg' : 'lb',
                  onPick: () => _pickExercise(_rows[i]),
                  onMuscleChanged: (v) => setState(() => _rows[i].muscle = v),
                  onRemove: () => setState(() {
                    _rows.removeAt(i).dispose();
                  }),
                ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: _editing ? 'Save changes' : 'Save workout',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseEditor extends StatelessWidget {
  final _ExerciseRow row;
  final String weightUnit;
  final VoidCallback onPick;
  final ValueChanged<String?> onMuscleChanged;
  final VoidCallback onRemove;

  const _ExerciseEditor({
    super.key,
    required this.row,
    required this.weightUnit,
    required this.onPick,
    required this.onMuscleChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Exercise',
                    suffixIcon: IconButton(
                      tooltip: 'Choose from library',
                      onPressed: onPick,
                      icon: const Icon(Icons.menu_book_rounded),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove exercise',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // Rebuilt when a library pick sets the muscle group.
            key: ValueKey(row.muscle),
            value: row.muscle,
            decoration: const InputDecoration(labelText: 'Muscle group'),
            items: [
              for (final g in AppConstants.muscleGroups)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: onMuscleChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.sets,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sets'),
                  validator: Validators.optionalInt,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                  validator: Validators.optionalInt,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: weightUnit),
                  validator: Validators.optionalNumber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
