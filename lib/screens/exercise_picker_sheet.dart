import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/exercise_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Searchable list of built-in and custom exercises. Returns the chosen one,
/// or null if the sheet was closed.
Future<ExerciseDef?> showExercisePicker(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showModalBottomSheet<ExerciseDef>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: ExercisePickerSheet(initialQuery: initialQuery),
    ),
  );
}

class ExercisePickerSheet extends StatefulWidget {
  final String initialQuery;

  const ExercisePickerSheet({super.key, this.initialQuery = ''});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery);
  String? _muscle;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _addCustom() async {
    final created = await showAddExerciseDialog(
      context,
      name: _query.text,
      muscleGroup: _muscle,
    );
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<ExerciseProvider>();
    final results = library.search(_query.text, muscleGroup: _muscle);
    final exact = library.find(_query.text) != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _query,
              autofocus: widget.initialQuery.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final g in [null, ...AppConstants.muscleGroups])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g ?? 'All'),
                      selected: _muscle == g,
                      onSelected: (_) => setState(() => _muscle = g),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                if (_query.text.trim().isNotEmpty && !exact)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.primary),
                    title: Text('Add "${_query.text.trim()}" as a new exercise'),
                    onTap: _addCustom,
                  ),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No exercises match.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.muted),
                    ),
                  ),
                for (final e in results)
                  ListTile(
                    title: Text(e.name),
                    subtitle: Text(e.muscleGroup),
                    trailing: e.isCustom
                        ? Icon(Icons.person_outline_rounded,
                            size: 18, color: context.faint)
                        : null,
                    onTap: () => Navigator.of(context).pop(e),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog to create a custom exercise. Returns it, or null if cancelled.
Future<ExerciseDef?> showAddExerciseDialog(
  BuildContext context, {
  String name = '',
  String? muscleGroup,
}) {
  return showDialog<ExerciseDef>(
    context: context,
    builder: (_) => _AddExerciseDialog(name: name, muscleGroup: muscleGroup),
  );
}

class _AddExerciseDialog extends StatefulWidget {
  final String name;
  final String? muscleGroup;

  const _AddExerciseDialog({required this.name, this.muscleGroup});

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.name.trim());
  late String _muscle = widget.muscleGroup ?? AppConstants.muscleGroups.first;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final def =
          await context.read<ExerciseProvider>().addCustom(_name.text, _muscle);
      if (mounted) Navigator.of(context).pop(def);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New exercise'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _muscle,
            decoration: const InputDecoration(labelText: 'Muscle group'),
            items: [
              for (final g in AppConstants.muscleGroups)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _muscle = v ?? _muscle),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
