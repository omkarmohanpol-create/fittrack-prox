import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/exercise_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import 'exercise_picker_sheet.dart';

/// Browse the library and manage your own exercises.
class ExerciseLibraryScreen extends StatelessWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<ExerciseProvider>();
    final all = library.all;

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise library')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showAddExerciseDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New exercise'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final group in AppConstants.muscleGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                group.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: context.muted,
                ),
              ),
            ),
            for (final e in all.where((e) => e.muscleGroup == group))
              e.isCustom
                  ? Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final error = await library.removeCustom(e.id!);
                        if (error != null) {
                          messenger.showSnackBar(SnackBar(content: Text(error)));
                        }
                        return error == null;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.redAccent.withOpacity(0.85),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white),
                      ),
                      child: ListTile(
                        title: Text(e.name),
                        trailing: Text('Yours · swipe to delete',
                            style: TextStyle(fontSize: 12, color: context.faint)),
                      ),
                    )
                  : ListTile(title: Text(e.name)),
          ],
        ],
      ),
    );
  }
}
