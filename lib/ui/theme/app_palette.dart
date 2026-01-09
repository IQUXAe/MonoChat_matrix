import 'package:flutter/cupertino.dart';

abstract class AppPalette {
  Color get scaffoldBackground;
  Color get barBackground;
  Color get primary;
  Color get text;
  Color get secondaryText;
  Color get separator;
  Color get inputBackground;
  Color get glassBackground;
}

class LightPalette implements AppPalette {
  final Color? _primary;
  const LightPalette({Color? primary}) : _primary = primary;

  @override
  Color get scaffoldBackground => CupertinoColors.systemBackground;
  @override
  Color get barBackground => CupertinoColors.systemGroupedBackground;
  @override
  Color get primary => _primary ?? CupertinoColors.activeBlue;
  @override
  Color get text => CupertinoColors.black;
  @override
  Color get secondaryText => CupertinoColors.systemGrey;
  @override
  Color get separator => CupertinoColors.separator;
  @override
  Color get inputBackground => CupertinoColors.systemGrey6;
  @override
  Color get glassBackground => CupertinoColors.white.withValues(alpha: 0.30);
}

class DarkPalette implements AppPalette {
  final Color? _primary;
  const DarkPalette({Color? primary}) : _primary = primary;

  @override
  Color get scaffoldBackground => const Color(0xFF1C1C1E);
  @override
  Color get barBackground => const Color(0xFF2C2C2E);
  @override
  Color get primary => _primary ?? CupertinoColors.activeBlue;
  @override
  Color get text => CupertinoColors.white;
  @override
  Color get secondaryText => CupertinoColors.systemGrey;
  @override
  Color get separator => CupertinoColors.separator;
  @override
  Color get inputBackground => const Color(0xFF2C2C2E);
  @override
  Color get glassBackground => CupertinoColors.black.withValues(alpha: 0.30);
}
