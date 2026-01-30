import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

class AppIconService {
  // Android Activity Aliases
  static const String _androidIconLight = 'MainActivity';
  static const String _androidIconDark = 'MainActivityDark';

  // iOS Icon Keys
  static const String _iosIconDark = 'dark';

  static final AppIconService _instance = AppIconService._internal();
  factory AppIconService() => _instance;
  AppIconService._internal();

  Future<void> setLightIcon() async {
    try {
      if (Platform.isAndroid) {
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: _androidIconLight,
        );
      } else if (Platform.isIOS) {
        await FlutterDynamicIconPlus.setAlternateIconName(iconName: null);
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to set light icon: $e');
    }
  }

  Future<void> setDarkIcon() async {
    try {
      if (Platform.isAndroid) {
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: _androidIconDark,
        );
      } else if (Platform.isIOS) {
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: _iosIconDark,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to set dark icon: $e');
    }
  }

  Future<String?> getCurrentIcon() async {
    try {
      return await FlutterDynamicIconPlus.alternateIconName;
    } catch (_) {
      return null;
    }
  }
}
