import 'package:flutter/cupertino.dart';
import 'package:monochat/ui/theme/app_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static const String _themeKey = 'app_theme_mode';
  static const String _textScaleKey = 'app_text_scale';
  static const String _primaryColorKey = 'app_primary_color';
  AppThemeMode _currentTheme = AppThemeMode.system;
  double _textScale = 1.0;
  Color? _customPrimaryColor;
  bool get useAppleEmojis => false;

  ThemeController() {
    _loadTheme();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_currentTheme == AppThemeMode.system) {
      notifyListeners();
    }
    super.didChangePlatformBrightness();
  }

  AppThemeMode get themeMode => _currentTheme;

  // Derive brightness for CupertinoThemeData based on mode
  Brightness? get brightness {
    switch (_currentTheme) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return null; // Lets CupertinoApp use system setting
    }
  }

  double get textScale => _textScale;

  Color? get customPrimaryColor => _customPrimaryColor;

  /// Returns the current active palette.
  ///
  /// If mode is [AppThemeMode.system], it resolves based on
  /// [WidgetsBinding.instance.platformDispatcher.platformBrightness].
  AppPalette get palette {
    if (_currentTheme == AppThemeMode.light) {
      return LightPalette(primary: _customPrimaryColor);
    } else if (_currentTheme == AppThemeMode.dark) {
      return DarkPalette(primary: _customPrimaryColor);
    } else {
      // System mode
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark
          ? DarkPalette(primary: _customPrimaryColor)
          : LightPalette(primary: _customPrimaryColor);
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey);
    if (themeString != null) {
      _currentTheme = AppThemeMode.values.firstWhere(
        (e) => e.name == themeString,
        orElse: () => AppThemeMode.system,
      );
    }

    final scale = prefs.getDouble(_textScaleKey);
    if (scale != null) {
      _textScale = scale;
    }

    final colorValue = prefs.getInt(_primaryColorKey);
    if (colorValue != null) {
      _customPrimaryColor = Color(colorValue);
    }

    notifyListeners();
  }

  Future<void> setTextScale(double scale) async {
    if (_textScale == scale) return;
    _textScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, scale);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_currentTheme == mode) return;

    _currentTheme = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> setPrimaryColor(Color? color) async {
    if (_customPrimaryColor == color) return;

    _customPrimaryColor = color;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_primaryColorKey);
    } else {
      await prefs.setInt(_primaryColorKey, color.toARGB32());
    }
  }
}
