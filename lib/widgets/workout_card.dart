import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/settings_provider.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  /// Should delete the workout and return true only if it was deleted.
  final Future<bool> Function()? onDelete;
  final VoidCallback? onTap;

  /// Saved on this phone but not uploaded yet.
  final bool pending;

  const WorkoutCard({
    super.key,
    required this.workout,
    this.onDelete,
    this.onTap,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final metric = context.watch<SettingsProvider>().useMetric;
    final color = workout.isCardio ? AppColors.cardio : AppColors.workouts;
    final details = <String>[
      Formatters.longDate(workout.date),
      if (workout.durationMinutes > 0) Formatters.duration(workout.durationMinutes),
      if (workout.caloriesBurned > 0) '${workout.caloriesBurned} kcal',
      if (workout.volume > 0) Formatters.weight(workout.volume, metric),
    ];

    final box = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              workout.isCardio
                  ? Icons.directions_run_rounded
                  : Icons.fitness_center_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        workout.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Saved on this phone, not synced yet',
                        child: Icon(Icons.cloud_off_rounded,
                            size: 16, color: context.faint),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  details.join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final card = onTap == null
        ? box
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: box,
            ),
          );

    if (onDelete == null) return card;
    return Dismissible(
      key: ValueKey(workout.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: card,
    );
  }
}
