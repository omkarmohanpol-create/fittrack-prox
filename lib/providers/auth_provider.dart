import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/local_store.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _guest = false;
  bool _loading = false;
  bool _sessionExpired = false;
  String _fullName = '';
  String _fitnessLevel = 'beginner';
  String? _avatarUrl;
  StreamSubscription<AuthState>? _sub;

  AuthProvider() {
    if (SupabaseService.isConfigured) {
      _user = SupabaseService.client.auth.currentUser;
      _sub = SupabaseService.client.auth.onAuthStateChange.listen(
        (state) => handleAuthChange(state.event, state.session?.user),
        // A failed token refresh (for example no network) can arrive as a
        // stream error. The SDK keeps retrying; only a signedOut event ends
        // the session, so errors are ignored here.
        onError: (Object _) {},
      );
      if (_user != null) loadProfile();
    }
  }

  /// Applies a Supabase auth event. Public for tests.
  @visibleForTesting
  void handleAuthChange(AuthChangeEvent event, User? user) {
    final hadUser = _user != null;
    _user = user;

    if (user == null) {
      if (hadUser) {
        // signOut() clears _user before it calls Supabase, so getting here
        // with a user still set means the session ended on its own: the
        // refresh token expired or was revoked, or the account was removed.
        _sessionExpired = true;
        _guest = false;
        _resetProfile();
      }
      notifyListeners();
      return;
    }

    _sessionExpired = false;
    if (event == AuthChangeEvent.tokenRefreshed) {
      notifyListeners(); // same user, no need to refetch the profile
      return;
    }
    loadProfile();
  }

  bool get isConfigured => SupabaseService.isConfigured;
  bool get isAuthenticated => _user != null || _guest;
  bool get isGuest => _guest && _user == null;
  bool get isLoading => _loading;

  /// True after the session ended without the user signing out. The app
  /// sends them back to login (see SessionExpiryListener) and then calls
  /// [acknowledgeSessionExpired].
  bool get sessionExpired => _sessionExpired;

  void acknowledgeSessionExpired() => _sessionExpired = false;

  String? get userId => _user?.id;
  String get email => _user?.email ?? '';
  String get fitnessLevel => _fitnessLevel;
  String? get avatarUrl => _avatarUrl;

  void _resetProfile() {
    _fullName = '';
    _fitnessLevel = 'beginner';
    _avatarUrl = null;
  }

  String get displayName {
    if (_fullName.trim().isNotEmpty) return _fullName.trim();
    if (_user?.email != null) return _user!.email!.split('@').first;
    return 'Athlete';
  }

  String get initial => displayName.isEmpty ? '?' : displayName[0].toUpperCase();

  Future<void> loadProfile() async {
    try {
      final row = await SupabaseService.fetchProfile();
      if (row != null) {
        _fullName = (row['full_name'] as String?) ?? '';
        _fitnessLevel = (row['fitness_level'] as String?) ?? 'beginner';
        _avatarUrl = row['avatar_url'] as String?;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<AuthResult> signIn(String email, String password) async {
    _loading = true;
    notifyListeners();
    final result = await AuthService.signIn(email, password);
    _loading = false;
    if (result.success) {
      _user = SupabaseService.client.auth.currentUser;
      await loadProfile();
    }
    notifyListeners();
    return result;
  }

  Future<AuthResult> signUp(String email, String password, String name) async {
    _loading = true;
    notifyListeners();
    final result = await AuthService.signUp(email, password, name);
    _loading = false;
    if (result.success) {
      _user = SupabaseService.client.auth.currentUser;
      if (_user != null) {
        _fullName = name.trim();
        await loadProfile();
      }
    }
    notifyListeners();
    return result;
  }

  /// Opens Google sign-in in the browser. On success Supabase reports the new
  /// session through the auth stream, which signs the user in here.
  Future<AuthResult> signInWithGoogle() => AuthService.signInWithGoogle();

  /// Local-only mode: data stays on this device and is not synced.
  void continueAsGuest() {
    _guest = true;
    notifyListeners();
  }

  Future<void> updateProfile(String fullName, String level) async {
    _fullName = fullName.trim();
    _fitnessLevel = level;
    notifyListeners();
    if (SupabaseService.canSync) {
      await SupabaseService.updateProfile(
        fullName: _fullName,
        fitnessLevel: level,
      );
    }
  }

  void setAvatarUrl(String? url) {
    _avatarUrl = url;
    notifyListeners();
  }

  /// Signs out and removes this account's cached and unsynced data from the
  /// device (the Settings screen warns first if anything is unsynced).
  Future<void> signOut() async {
    final uid = _user?.id;
    final hadSession = SupabaseService.isConfigured && uid != null;
    // Clear first, so the signedOut event this triggers is not mistaken for
    // an expired session.
    _user = null;
    _guest = false;
    _sessionExpired = false;
    _resetProfile();
    notifyListeners();
    if (uid != null) await LocalStore.clearUser(uid);
    if (hadSession) {
      try {
        await AuthService.signOut();
      } catch (_) {
        // The SDK removes the local session even when the server call fails
        // (for example offline), so the user is signed out either way.
      }
    }
  }

  /// Deletes the Supabase account and all of its data. Returns null on
  /// success, or an error message.
  Future<String?> deleteAccount() async {
    final uid = _user?.id;
    if (uid == null) return 'You are not signed in.';
    try {
      await SupabaseService.deleteAccount();
    } catch (_) {
      return 'Could not delete your account. Check your connection and try again.';
    }
    _user = null;
    _guest = false;
    _sessionExpired = false;
    _resetProfile();
    notifyListeners();
    await LocalStore.clearUser(uid);
    try {
      await AuthService.signOut();
    } catch (_) {}
    return null;
  }

  /// Guest mode: removes everything the guest saved on this device.
  Future<void> deleteGuestData() async {
    await LocalStore.clearGuest();
    _guest = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
