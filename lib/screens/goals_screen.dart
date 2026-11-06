import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/goal_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/steps_provider.dart';
import '../providers/water_provider.dart';
import '../providers/workout_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/goal_card.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  Future<void> _editGoal(
    BuildContext context, {
    required String title,
    required String suffix,
    required int current,
    required String type,
  }) async {
    final controller = TextEditingController(text: '$current');
    final goals = context.read<GoalProvider>();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value > 0) {
      await goals.setGoal(type, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalProvider>();
    final workouts = context.watch<WorkoutProvider>();
    final water = context.watch<WaterProvider>();
    final settings = context.watch<SettingsProvider>();
    final steps = context.watch<StepsProvider>();
    final stepsGoal = goals.stepsGoal;

    final weekCount = workouts.workoutsInLastDays(7);
    final weekGoal = goals.workoutsPerWeekGoal;
    final waterGoal = goals.waterGoalMl;

    final badges = <_Badge>[
      _Badge('First workout', Icons.emoji_events_rounded, workouts.totalWorkouts >= 1),
      _Badge('10 workouts', Icons.military_tech_rounded, workouts.totalWorkouts >= 10),
      _Badge('7-day streak', Icons.local_fire_department_rounded,
          workouts.currentStreak >= 7),
      _Badge('Weekly goal', Icons.flag_rounded, weekCount >= weekGoal),
      _Badge('Hydrated', Icons.water_drop_rounded, water.todayMl >= waterGoal),
      if (steps.isEnabled)
        _Badge('Step goal', Icons.directions_walk_rounded,
            steps.todaySteps >= stepsGoal),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          GoalCard(
            icon: Icons.fitness_center_rounded,
            color: AppColors.workouts,
            title: 'Workouts per week',
            progressText: '$weekCount of $weekGoal in the last 7 days',
            progress: weekGoal == 0 ? 0 : weekCount / weekGoal,
            onEdit: () => _editGoal(
              context,
              title: 'Workouts per week',
              suffix: 'per week',
              current: weekGoal,
              type: GoalType.workoutsPerWeek,
            ),
          ),
          const SizedBox(height: 12),
          GoalCard(
            icon: Icons.water_drop_rounded,
            color: AppColors.water,
            title: 'Daily water',
            progressText:
                '${Formatters.volumeMl(water.todayMl)} of ${Formatters.volumeMl(waterGoal)} today',
            progress: waterGoal == 0 ? 0 : water.todayMl / waterGoal,
            onEdit: () => _editGoal(
              context,
              title: 'Daily water goal',
              suffix: 'ml',
              current: waterGoal,
              type: GoalType.waterDaily,
            ),
          ),
          if (steps.isEnabled) ...[
            const SizedBox(height: 12),
            GoalCard(
              icon: Icons.directions_walk_rounded,
              color: AppColors.steps,
              title: 'Daily steps',
              progressText:
                  '${Formatters.compact(steps.todaySteps)} of ${Formatters.compact(stepsGoal)} today',
              progress: stepsGoal == 0 ? 0 : steps.todaySteps / stepsGoal,
              onEdit: () => _editGoal(
                context,
                title: 'Daily step goal',
                suffix: 'steps',
                current: stepsGoal,
                type: GoalType.stepsDaily,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Achievements',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final b in badges) _BadgeChip(badge: b)],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Reminders',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily workout reminder'),
            subtitle: Text(settings.workoutTime.format(context)),
            value: settings.workoutReminder,
            onChanged: settings.setWorkoutReminder,
          ),
          if (settings.workoutReminder)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: settings.workoutTime,
                  );
                  if (picked != null) await settings.setWorkoutTime(picked);
                },
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Change time'),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Water reminders'),
            subtitle: const Text('Every 2 hours, 9:00 to 21:00'),
            value: settings.waterReminder,
            onChanged: settings.setWaterReminder,
          ),
        ],
      ),
    );
  }
}

class _Badge {
  final String label;
  final IconData icon;
  final bool earned;

  const _Badge(this.label, this.icon, this.earned);
}

class _BadgeChip extends StatelessWidget {
  final _Badge badge;

  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.earned ? AppColors.accent : context.faint;
    return Semantics(
      label: '${badge.label}: ${badge.earned ? 'earned' : 'locked'}',
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge.earned ? AppColors.accent : context.borderColor,
          ),
        ),
        child: Column(
          children: [
            Icon(badge.icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: badge.earned ? null : context.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
