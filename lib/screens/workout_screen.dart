import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workout_provider.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/workout_card.dart';
import 'exercise_library_screen.dart';
import 'log_workout_sheet.dart';
import 'workout_timer_screen.dart';

/// Opens the workout timer; when it is finished, opens the log sheet with the
/// elapsed minutes filled in.
Future<void> startTimedWorkout(BuildContext context) async {
  final elapsed = await Navigator.of(context).push<Duration>(
    MaterialPageRoute(builder: (_) => const WorkoutTimerScreen()),
  );
  if (elapsed != null && context.mounted) {
    await showLogWorkoutSheet(context, minutes: Formatters.minutesFor(elapsed));
  }
}

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final items = provider.workouts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          IconButton(
            tooltip: 'Workout timer',
            onPressed: () => startTimedWorkout(context),
            icon: const Icon(Icons.timer_outlined),
          ),
          IconButton(
            tooltip: 'Exercise library',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
            ),
            icon: const Icon(Icons.menu_book_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null, // two FABs share the IndexedStack in HomeShell
        tooltip: 'Log workout',
        onPressed: () => showLogWorkoutSheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.fitness_center_rounded,
                      size: 56, color: context.faint),
                  const SizedBox(height: 16),
                  Text(
                    provider.error ?? 'Nothing logged yet.\nTap + to add a workout.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.muted),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  96,
                ),
                itemCount: items.length + (provider.isOffline ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  if (provider.isOffline) {
                    if (i == 0) return const _OfflineNote();
                    i--;
                  }
                  final w = items[i];
                  return WorkoutCard(
                    workout: w,
                    pending: provider.isPending(w.id),
                    onTap: () => showLogWorkoutSheet(context, workout: w),
                    onDelete: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await provider.remove(w.id);
                      if (error != null) {
                        messenger.showSnackBar(SnackBar(content: Text(error)));
                      }
                      return error == null;
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 16, color: context.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Offline: showing saved data. New workouts sync when you are back online.',
            style: TextStyle(fontSize: 12, color: context.muted),
          ),
        ),
      ],
    );
  }
}
