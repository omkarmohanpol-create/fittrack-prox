import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/steps_provider.dart';
import '../providers/water_provider.dart';
import '../providers/workout_provider.dart';
import '../services/chart_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/progress_chart.dart';
import '../widgets/stat_card.dart';
import '../widgets/user_avatar.dart';
import '../widgets/workout_card.dart';
import 'log_workout_sheet.dart';

class DashboardScreen extends StatelessWidget {
  /// Switches the bottom-nav tab (1 workouts, 2 progress, 3 water, 4 goals).
  final ValueChanged<int> onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final workouts = context.watch<WorkoutProvider>();
    final water = context.watch<WaterProvider>();
    final goals = context.watch<GoalProvider>();
    final steps = context.watch<StepsProvider>();

    final now = DateTime.now();
    final challenge = AppConstants.dailyChallenges[
        now.difference(DateTime(now.year)).inDays %
            AppConstants.dailyChallenges.length];
    final weekSeries =
        ChartService.build(workouts.workouts, ChartRange.d7, ChartMetric.minutes);
    final recent = workouts.workouts.take(3).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Log workout',
        onPressed: () => showLogWorkoutSheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await workouts.load();
            await water.load();
            await goals.load();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.greeting(now),
                          style: TextStyle(color: context.muted, fontSize: 14),
                        ),
                        Text(
                          auth.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => Navigator.of(context).pushNamed('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  Semantics(
                    button: true,
                    label: 'Profile',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/profile'),
                      child: const UserAvatar(radius: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Challenge
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's challenge",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            challenge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (workouts.currentStreak > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              '${workouts.currentStreak}-day streak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onNavigate(4),
                      child: StatCard(
                        icon: Icons.fitness_center_rounded,
                        color: AppColors.workouts,
                        value:
                            '${workouts.workoutsInLastDays(7)}/${goals.workoutsPerWeekGoal}',
                        label: 'This week',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onNavigate(3),
                      child: StatCard(
                        icon: Icons.water_drop_rounded,
                        color: AppColors.water,
                        value: Formatters.volumeMl(water.todayMl),
                        label: 'Water today',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.calories,
                      value: '${workouts.caloriesToday}',
                      label: 'kcal today',
                    ),
                  ),
                ],
              ),
              if (steps.isSupported) ...[
                const SizedBox(height: 12),
                _StepsCard(steps: steps, goal: goals.stepsGoal),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Week strip
              const Text(
                'This week',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _WeekStrip(workouts: workouts),
              const SizedBox(height: AppSpacing.lg),

              // Chart
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Active minutes',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigate(2),
                    child: const Text('Details'),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: ProgressChart(series: weekSeries, height: 180),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Recent
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent workouts',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigate(1),
                    child: const Text('See all'),
                  ),
                ],
              ),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No workouts yet. Tap + to log your first one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.muted),
                  ),
                )
              else
                for (final w in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: WorkoutCard(
                      workout: w,
                      pending: workouts.isPending(w.id),
                      onTap: () => showLogWorkoutSheet(context, workout: w),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final WorkoutProvider workouts;

  const _WeekStrip({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final today = Formatters.dateOnly(DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final d in days)
          Semantics(
            label:
                '${Formatters.longDate(d)}: ${workouts.hasWorkoutOn(d) ? 'workout done' : 'no workout'}',
            child: Column(
              children: [
                Text(
                  Formatters.shortDay(d).substring(0, 1),
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient:
                        workouts.hasWorkoutOn(d) ? AppColors.gradient : null,
                    shape: BoxShape.circle,
                    border: workouts.hasWorkoutOn(d)
                        ? null
                        : Border.all(
                            color: d == today
                                ? AppColors.primary
                                : context.borderColor,
                            width: d == today ? 2 : 1,
                          ),
                  ),
                  alignment: Alignment.center,
                  child: workouts.hasWorkoutOn(d)
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : Text(
                          '${d.day}',
                          style: TextStyle(fontSize: 12, color: context.muted),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepsCard extends StatelessWidget {
  final StepsProvider steps;
  final int goal;

  const _StepsCard({required this.steps, required this.goal});

  @override
  Widget build(BuildContext context) {
    final today = steps.todaySteps;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: steps.isEnabled
          ? Row(
              children: [
                const Icon(Icons.directions_walk_rounded,
                    color: AppColors.steps, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${Formatters.compact(today)} steps',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: goal == 0 ? 0 : (today / goal).clamp(0.0, 1.0),
                        color: AppColors.steps,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Goal ${Formatters.compact(goal)}',
                        style: TextStyle(fontSize: 12, color: context.muted),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.directions_walk_rounded,
                    color: AppColors.steps, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps.permissionDenied
                        ? 'Step counting needs the physical activity permission.'
                        : 'Count your daily steps with the phone\'s step sensor.',
                    style: TextStyle(fontSize: 13, color: context.muted),
                  ),
                ),
                TextButton(
                  onPressed: steps.enable,
                  child: const Text('Turn on'),
                ),
              ],
            ),
    );
  }
}
