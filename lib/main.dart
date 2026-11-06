import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/exercise_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/measurement_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/steps_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/water_provider.dart';
import 'providers/workout_provider.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';
import 'widgets/session_expiry_listener.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase credentials come from --dart-define; without them the app runs
  // in local-only guest mode.
  await SupabaseService.initialize();
  await NotificationService.instance.init();

  runApp(const FitTrackApp());
}

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => MeasurementProvider()),
        ChangeNotifierProvider(create: (_) => StepsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            scaffoldMessengerKey: _messengerKey,
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => SessionExpiryListener(
              navigatorKey: _navigatorKey,
              messengerKey: _messengerKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const SplashScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/home': (_) => const HomeShell(),
              '/settings': (_) => const SettingsScreen(),
              '/profile': (_) => const ProfileScreen(),
            },
          );
        },
      ),
    );
  }
}
