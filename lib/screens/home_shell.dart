import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/exercise_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/measurement_provider.dart';
import '../providers/steps_provider.dart';
import '../providers/water_provider.dart';
import '../providers/workout_provider.dart';
import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'progress_screen.dart';
import 'water_screen.dart';
import 'workout_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
    _lifecycle = AppLifecycleListener(
      // Upload anything saved offline as soon as the app is back.
      onResume: () {
        if (!mounted) return;
        context.read<WorkoutProvider>().syncPending();
        context.read<WaterProvider>().syncPending();
      },
      onPause: () {
        if (mounted) context.read<StepsProvider>().flush();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _loadAll() {
    if (!mounted) return;
    context.read<WorkoutProvider>().load();
    context.read<WaterProvider>().load();
    context.read<GoalProvider>().load();
    context.read<ExerciseProvider>().load();
    context.read<MeasurementProvider>().load();
    context.read<StepsProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onNavigate: (i) => setState(() => _index = i)),
          const WorkoutScreen(),
          const ProgressScreen(),
          const WaterScreen(),
          const GoalsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            selectedIcon: Icon(Icons.stacked_line_chart_rounded),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop_rounded),
            label: 'Water',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded),
            label: 'Goals',
          ),
        ],
      ),
    );
  }
}
