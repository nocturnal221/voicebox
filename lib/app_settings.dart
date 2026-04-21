import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _themeModeKey = 'theme_mode';
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey) ?? 'light';
    themeMode.value = _parseThemeMode(raw);
  }

  static Future<void> toggleThemeMode() async {
    final next =
        themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    themeMode.value = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, next.name);
  }

  static ThemeMode _parseThemeMode(String raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}
