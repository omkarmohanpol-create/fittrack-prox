import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/measurement_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/steps_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/water_provider.dart';
import '../providers/workout_provider.dart';
import '../services/local_store.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final workouts = context.read<WorkoutProvider>().workouts;
    if (workouts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No workouts to export yet')),
      );
      return;
    }

    final rows = <List<dynamic>>[
      [
        'Date',
        'Type',
        'Workout',
        'Duration (min)',
        'Calories',
        'Exercise',
        'Muscle group',
        'Sets',
        'Reps',
        'Weight (kg)',
      ],
      for (final w in workouts)
        if (w.exercises.isEmpty)
          [
            Formatters.isoDate(w.date),
            w.type,
            w.name,
            w.durationMinutes,
            w.caloriesBurned,
            '',
            '',
            '',
            '',
            '',
          ]
        else
          for (final e in w.exercises)
            [
              Formatters.isoDate(w.date),
              w.type,
              w.name,
              w.durationMinutes,
              w.caloriesBurned,
              e.name,
              e.muscleGroup ?? '',
              e.sets,
              e.reps,
              e.weightKg,
            ],
    ];

    try {
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fittrack_workouts.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'FitTrack Pro workout history',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not export your data')),
      );
    }
  }

  /// Clears every data provider and goes back to the login screen.
  void _leave(BuildContext context, {String? message}) {
    context.read<WorkoutProvider>().clear();
    context.read<WaterProvider>().clear();
    context.read<GoalProvider>().clear();
    context.read<ExerciseProvider>().clear();
    context.read<MeasurementProvider>().clear();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid != null) {
      final pending = await LocalStore.pendingCount(uid);
      if (pending > 0) {
        if (!context.mounted) return;
        final ok = await _confirm(
          context,
          title: 'Sign out anyway?',
          body: '$pending ${pending == 1 ? 'entry was' : 'entries were'} saved '
              'offline and not synced yet. Signing out deletes '
              '${pending == 1 ? 'it' : 'them'} from this phone.',
          action: 'Sign out',
        );
        if (!ok) return;
      }
    }
    await auth.signOut();
    if (context.mounted) _leave(context);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Delete your account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes your account, workouts, water log, '
                'goals, measurements, steps and profile picture. It cannot be '
                'undone.\n\nType DELETE to confirm.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typed,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: typed.text.trim() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
    typed.dispose();
    if (ok != true) return;

    final error = await auth.deleteAccount();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (context.mounted) _leave(context, message: 'Your account was deleted.');
  }

  Future<void> _deleteGuestData(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: 'Delete data on this phone?',
      body: 'This removes every workout, water entry, measurement and goal '
          'saved in guest mode. It cannot be undone.',
      action: 'Delete',
    );
    if (!ok || !context.mounted) return;
    await context.read<AuthProvider>().deleteGuestData();
    if (context.mounted) _leave(context, message: 'Guest data deleted.');
  }

  Future<void> _toggleSteps(BuildContext context, bool on) async {
    final steps = context.read<StepsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (!on) return steps.disable();
    final ok = await steps.enable();
    if (!ok && steps.permissionDenied) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Allow physical activity access to count steps.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => openAppSettings(),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final steps = context.watch<StepsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _Section('Appearance'),
          SwitchListTile(
            title: const Text('Dark mode'),
            value: theme.isDarkMode,
            onChanged: theme.setDarkMode,
          ),
          SwitchListTile(
            title: const Text('Metric units'),
            subtitle: Text(settings.useMetric ? 'Kilograms' : 'Pounds'),
            value: settings.useMetric,
            onChanged: settings.setMetric,
          ),
          const _Section('Notifications'),
          SwitchListTile(
            title: const Text('Daily workout reminder'),
            subtitle: Text(settings.workoutTime.format(context)),
            value: settings.workoutReminder,
            onChanged: settings.setWorkoutReminder,
          ),
          SwitchListTile(
            title: const Text('Water reminders'),
            value: settings.waterReminder,
            onChanged: settings.setWaterReminder,
          ),
          const _Section('Activity'),
          SwitchListTile(
            title: const Text('Count steps'),
            subtitle: Text(steps.isSupported
                ? 'Uses the phone\'s step sensor'
                : 'Not available on this device'),
            value: steps.isEnabled,
            onChanged: steps.isSupported ? (v) => _toggleSteps(context, v) : null,
          ),
          const _Section('Data and privacy'),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Export workouts as CSV'),
            onTap: () => _exportCsv(context),
          ),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Privacy'),
            subtitle: Text(
              'No analytics or third-party sharing. Signed-in data is stored '
              'in your private Supabase account; guest data stays on this device.',
            ),
          ),
          const _Section('Account'),
          if (!auth.isGuest && auth.email.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: Text(auth.email),
            ),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Edit profile'),
            onTap: () => Navigator.of(context).pushNamed('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: Text(
              auth.isGuest ? 'Leave guest mode' : 'Sign out',
              style: const TextStyle(color: Colors.redAccent),
            ),
            onTap: () => _signOut(context),
          ),
          if (auth.isGuest)
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined,
                  color: Colors.redAccent),
              title: const Text('Delete data on this phone',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () => _deleteGuestData(context),
            )
          else if (auth.userId != null)
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined,
                  color: Colors.redAccent),
              title: const Text('Delete account',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () => _deleteAccount(context),
            ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppConstants.appName} v1.0.0',
              style: TextStyle(fontSize: 12, color: context.faint),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.muted,
        ),
      ),
    );
  }
}
