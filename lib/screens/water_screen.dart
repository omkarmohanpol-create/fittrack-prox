import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/goal_provider.dart';
import '../providers/water_provider.dart';
import '../services/chart_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/progress_chart.dart';
import '../widgets/water_ring.dart';

class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  Future<void> _add(BuildContext context, WaterProvider water, int ml) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await water.add(ml);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _undo(BuildContext context, WaterProvider water) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await water.undoLast();
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final water = context.watch<WaterProvider>();
    final goal = context.watch<GoalProvider>().waterGoalMl;

    final today = Formatters.dateOnly(DateTime.now());
    final totals = water.lastDays(7);
    final series = ChartSeries(
      [
        for (var i = 0; i < 7; i++)
          Formatters.shortDay(today.subtract(Duration(days: 6 - i))),
      ],
      [for (final ml in totals) ml / 1000],
    );
    final todays = water.logsFor(today);

    return Scaffold(
      appBar: AppBar(title: const Text('Water')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Center(child: WaterRing(currentMl: water.todayMl, goalMl: goal)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Remove last entry',
                iconSize: 28,
                onPressed: todays.isEmpty ? null : () => _undo(context, water),
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 20),
              const Text(
                '${AppConstants.waterStepMl} ml',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 20),
              IconButton.filled(
                tooltip: 'Add ${AppConstants.waterStepMl} ml',
                iconSize: 28,
                style: IconButton.styleFrom(backgroundColor: AppColors.water),
                onPressed: () => _add(context, water, AppConstants.waterStepMl),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final ml in const [150, 330, 500, 750])
                ActionChip(
                  label: Text('+$ml ml'),
                  onPressed: () => _add(context, water, ml),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Last 7 days (litres)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: ProgressChart(
              series: series,
              color: AppColors.water,
              height: 180,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            "Today's entries",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (todays.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Nothing logged yet today.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.muted),
              ),
            )
          else
            for (final log in todays)
              Dismissible(
                key: ValueKey(log.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  final messenger = ScaffoldMessenger.of(context);
                  final error = await water.remove(log.id);
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
                  leading: const Icon(Icons.water_drop_rounded,
                      color: AppColors.water),
                  title: Text(Formatters.volumeMl(log.amountMl)),
                ),
              ),
        ],
      ),
    );
  }
}
