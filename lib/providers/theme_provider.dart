import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../db/database_helper.dart';

enum AppThemeMode { light, dark, system }

AppThemeMode _themeModeFromString(String value) {
  switch (value) {
    case 'light':
      return AppThemeMode.light;
    case 'dark':
      return AppThemeMode.dark;
    default:
      return AppThemeMode.system;
  }
}

String _themeModeToString(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return 'light';
    case AppThemeMode.dark:
      return 'dark';
    case AppThemeMode.system:
      return 'system';
  }
}

class AppThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.system;
  Brightness _systemBrightness = Brightness.light;

  AppThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      await AppDatabase.instance.init();
      final stored = await AppDatabase.instance.getThemeMode();
      _mode = _themeModeFromString(stored);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load theme mode: $e');
    }
  }

  AppThemeMode get mode => _mode;

  bool get isDark => _mode == AppThemeMode.system ? _systemBrightness == Brightness.dark : _mode == AppThemeMode.dark;

  AppColors get colors => isDark ? kDarkColors : kLightColors;

  void updateSystemBrightness(Brightness brightness) {
    if (_systemBrightness != brightness) {
      _systemBrightness = brightness;
      if (_mode == AppThemeMode.system) notifyListeners();
    }
  }

  void setMode(AppThemeMode next) {
    _mode = next;
    notifyListeners();
    AppDatabase.instance.setThemeMode(_themeModeToString(next));
  }
}
