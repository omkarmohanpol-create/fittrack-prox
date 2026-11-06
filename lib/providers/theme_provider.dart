import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'dark_mode';

  bool _isDarkMode = true; // dark-first per DESIGN.md
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_key) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }
}
