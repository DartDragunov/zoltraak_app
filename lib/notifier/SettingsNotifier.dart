import 'package:flutter/material.dart';
import 'package:zoltraak_app/theme/Theme.dart';

enum AppThemeMode { dark, light, neonGreen, neonOrange }

class SettingsNotifier extends ChangeNotifier {
  static final SettingsNotifier _instance = SettingsNotifier._internal();
  ThemeData _themeMode = Themes.darkTheme;
  AppThemeMode _currentMode = AppThemeMode.dark;

  factory SettingsNotifier() {
    return _instance;
  }

  SettingsNotifier._internal();

  AppThemeMode get themeMode => _currentMode;
  ThemeData get themeData => _themeMode;

  void setThemeMode(AppThemeMode mode) {
    _currentMode = mode;
    switch (mode) {
      case AppThemeMode.dark:
        _themeMode = Themes.darkTheme;
        break;
      case AppThemeMode.light:
        _themeMode = Themes.lightTheme;
        break;
      case AppThemeMode.neonGreen:
        _themeMode = Themes.neonGreenTheme;
        break;
      case AppThemeMode.neonOrange:
        _themeMode = Themes.neonOrangeTheme;
        break;
    }
    notifyListeners();
  }
}
