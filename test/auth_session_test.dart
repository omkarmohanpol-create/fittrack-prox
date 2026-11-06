import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, User;
import 'package:fittrack_pro/providers/auth_provider.dart';
import 'package:fittrack_pro/providers/exercise_provider.dart';
import 'package:fittrack_pro/providers/goal_provider.dart';
import 'package:fittrack_pro/providers/measurement_provider.dart';
import 'package:fittrack_pro/providers/water_provider.dart';
import 'package:fittrack_pro/providers/workout_provider.dart';
import 'package:fittrack_pro/widgets/session_expiry_listener.dart';

// Supabase is not initialised in tests, so AuthProvider never subscribes to
// real auth events; the tests feed events in through handleAuthChange.
User _user() => const User(
      id: 'user-1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: 'omkar@example.com',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AuthProvider session expiry', () {
    test('a session that ends on its own is marked expired', () {
      final auth = AuthProvider();
      auth.handleAuthChange(AuthChangeEvent.signedIn, _user());
      expect(auth.isAuthenticated, isTrue);

      auth.handleAuthChange(AuthChangeEvent.signedOut, null);
      expect(auth.sessionExpired, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.email, isEmpty);
    });

    test('signing out yourself is not an expiry', () async {
      final auth = AuthProvider();
      auth.handleAuthChange(AuthChangeEvent.signedIn, _user());
      await auth.signOut();
      // Supabase fires signedOut after signOut(); it must be ignored.
      auth.handleAuthChange(AuthChangeEvent.signedOut, null);
      expect(auth.sessionExpired, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    test('a token refresh keeps the user signed in', () {
      final auth = AuthProvider();
      auth.handleAuthChange(AuthChangeEvent.signedIn, _user());
      auth.handleAuthChange(AuthChangeEvent.tokenRefreshed, _user());
      expect(auth.sessionExpired, isFalse);
      expect(auth.isAuthenticated, isTrue);
    });

    test('guest mode is not affected by signedOut events', () {
      final auth = AuthProvider()..continueAsGuest();
      auth.handleAuthChange(AuthChangeEvent.signedOut, null);
      expect(auth.sessionExpired, isFalse);
      expect(auth.isGuest, isTrue);
    });

    test('an expired user does not fall back to guest mode', () {
      final auth = AuthProvider()..continueAsGuest();
      auth.handleAuthChange(AuthChangeEvent.signedIn, _user());
      auth.handleAuthChange(AuthChangeEvent.signedOut, null);
      expect(auth.isGuest, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    test('signing in again clears the expired flag', () {
      final auth = AuthProvider();
      auth.handleAuthChange(AuthChangeEvent.signedIn, _user());
      auth.handleAuthChange(AuthChangeEvent.signedOut, null);
      auth.handleAuthChange(AuthChangeEvent.signedIn, _user());
      expect(auth.sessionExpired, isFalse);
    });
  });

  group('SessionExpiryListener', () {
    testWidgets('sends the user to login with a message', (tester) async {
      final auth = AuthProvider();
      final navigatorKey = GlobalKey<NavigatorState>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => WorkoutProvider()),
            ChangeNotifierProvider(create: (_) => WaterProvider()),
            ChangeNotifierProvider(create: (_) => GoalProvider()),
            ChangeNotifierProvider(create: (_) => ExerciseProvider()),
            ChangeNotifierProvider(create: (_) => MeasurementProvider()),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: messengerKey,
            builder: (context, child) => SessionExpiryListener(
              navigatorKey: navigatorKey,
              messengerKey: messengerKey,
              child: child!,
            ),
            home: const Scaffold(body: Text('home')),
            routes: {
              '/login': (_) => const Scaffold(body: Text('login')),
            },
          ),
        ),
      );

      auth.handleAuthChange(AuthChangeEvent.signedIn, _user());
      await tester.pump();
      expect(find.text('home'), findsOneWidget);

      auth.handleAuthChange(AuthChangeEvent.signedOut, null);
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
      expect(find.text('home'), findsNothing);
      expect(find.text(SessionExpiryListener.message), findsOneWidget);
      expect(auth.sessionExpired, isFalse); // acknowledged
    });

    testWidgets('signing out yourself does not show the message',
        (tester) async {
      final auth = AuthProvider();
      final navigatorKey = GlobalKey<NavigatorState>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => WorkoutProvider()),
            ChangeNotifierProvider(create: (_) => WaterProvider()),
            ChangeNotifierProvider(create: (_) => GoalProvider()),
            ChangeNotifierProvider(create: (_) => ExerciseProvider()),
            ChangeNotifierProvider(create: (_) => MeasurementProvider()),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: messengerKey,
            builder: (context, child) => SessionExpiryListener(
              navigatorKey: navigatorKey,
              messengerKey: messengerKey,
              child: child!,
            ),
            home: const Scaffold(body: Text('home')),
            routes: {
              '/login': (_) => const Scaffold(body: Text('login')),
            },
          ),
        ),
      );

      auth.handleAuthChange(AuthChangeEvent.signedIn, _user());
      await tester.pump();
      await auth.signOut();
      auth.handleAuthChange(AuthChangeEvent.signedOut, null);
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text(SessionExpiryListener.message), findsNothing);
    });
  });
}
