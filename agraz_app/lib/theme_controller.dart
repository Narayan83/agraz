import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKeyTheme = 'agraz_theme_mode';
const _prefsKeyNotifs = 'agraz_notifications_enabled';

/// App-wide theme + a few lightweight settings prefs. Default theme is light.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  ThemeMode _themeMode = ThemeMode.light;
  bool _notificationsEnabled = true;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKeyTheme) ?? 'light';
    _themeMode = switch (raw) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    _notificationsEnabled = p.getBool(_prefsKeyNotifs) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    final raw = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    await p.setString(_prefsKeyTheme, raw);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsKeyNotifs, enabled);
  }
}
