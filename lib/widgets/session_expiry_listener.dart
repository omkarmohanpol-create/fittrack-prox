import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/measurement_provider.dart';
import '../providers/water_provider.dart';
import '../providers/workout_provider.dart';

/// Sends the user back to the login screen when their Supabase session ends
/// without them signing out (the refresh token expired or was revoked).
///
/// Before this, the app stayed on the home screen and SupabaseService.canSync
/// turned false, so the providers quietly switched to the on-device guest
/// store: the user's cloud data disappeared from view and new workouts were
/// saved as guest data.
class SessionExpiryListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  const SessionExpiryListener({
    super.key,
    required this.navigatorKey,
    required this.messengerKey,
    required this.child,
  });

  static const message = 'Your session expired. Please sign in again.';

  @override
  State<SessionExpiryListener> createState() => _SessionExpiryListenerState();
}

class _SessionExpiryListenerState extends State<SessionExpiryListener> {
  AuthProvider? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_onAuthChanged);
      _auth = auth..addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (!mounted || auth == null || !auth.sessionExpired) return;
    auth.acknowledgeSessionExpired();

    // Take the signed-in user's data off the screen. The guest data saved on
    // the device is left alone.
    context.read<WorkoutProvider>().clear();
    context.read<WaterProvider>().clear();
    context.read<GoalProvider>().clear();
    context.read<ExerciseProvider>().clear();
    context.read<MeasurementProvider>().clear();

    // Removes every route, including an open log-workout sheet.
    widget.navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (_) => false);
    widget.messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(SessionExpiryListener.message)),
      );
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
