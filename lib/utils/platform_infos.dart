import 'dart:io';

import 'package:flutter/foundation.dart';

abstract class PlatformInfos {
  static bool get isWeb => kIsWeb;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isLinux || isWindows || isMacOS;

  static String get clientName {
    if (kIsWeb) return 'MonoChat Web';
    if (Platform.isAndroid) return 'MonoChat Android';
    if (Platform.isIOS) return 'MonoChat iOS';
    if (Platform.isLinux) return 'MonoChat Linux';
    if (Platform.isWindows) return 'MonoChat Windows';
    if (Platform.isMacOS) return 'MonoChat macOS';
    return 'MonoChat';
  }
}
