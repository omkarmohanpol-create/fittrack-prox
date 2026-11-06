import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/constants.dart';
import 'supabase_service.dart';

class AuthResult {
  final bool success;
  final String? message; // error text, or info such as "confirm your email"

  const AuthResult.ok([this.message]) : success = true;
  const AuthResult.fail(this.message) : success = false;
}

class AuthService {
  static GoTrueClient get _auth => SupabaseService.client.auth;

  static Future<AuthResult> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail('Could not reach the server. Try again.');
    }
  }

  static Future<AuthResult> signUp(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      if (res.session == null) {
        // Email confirmation is enabled in the Supabase project.
        return const AuthResult.ok(
          'Account created. Check your email to confirm, then sign in.',
        );
      }
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail('Could not reach the server. Try again.');
    }
  }

  /// Opens Google's sign-in page in the browser. The session arrives later
  /// through the fittrackpro://login-callback link, as an auth state change.
  static Future<AuthResult> signInWithGoogle() async {
    try {
      final opened = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConstants.authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return opened
          ? const AuthResult.ok()
          : const AuthResult.fail('Could not open the Google sign-in page.');
    } on AuthException catch (e) {
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail('Could not reach the server. Try again.');
    }
  }

  static Future<void> signOut({SignOutScope scope = SignOutScope.local}) =>
      _auth.signOut(scope: scope);
}
