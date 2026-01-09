import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:logging/logging.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/room_list_controller.dart';
import 'package:monochat/data/repositories/matrix_auth_repository.dart';
import 'package:monochat/data/repositories/matrix_room_repository.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:monochat/ui/screens/home_screen.dart';
import 'package:monochat/ui/screens/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging based on build mode
  _setupLogging();

  // Dependency Injection Root
  final matrixService = MatrixService();
  final authRepository = MatrixAuthRepository(matrixService);
  final roomRepository = MatrixRoomRepository(matrixService);

  runApp(
    MultiProvider(
      providers: [
        // Provide the MatrixService for widgets that need direct client access
        Provider.value(value: matrixService),
        ChangeNotifierProvider(create: (_) => AuthController(authRepository)),
        ChangeNotifierProvider(
          create: (_) => RoomListController(roomRepository),
        ),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const MonoChatApp(),
    ),
  );
}

/// Configures logging based on build mode.
///
/// - Debug: Shows all log levels in console
/// - Release: Logging is completely disabled for performance
void _setupLogging() {
  if (kReleaseMode) {
    // Completely disable logging in release mode
    Logger.root.level = Level.OFF;
    return;
  }

  // Debug mode: show all logs
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String().substring(11, 23);
    final level = record.level.name.padRight(7);
    final message = '[$time] $level ${record.loggerName}: ${record.message}';

    if (record.error != null) {
      debugPrint('$message\n  Error: ${record.error}');
      if (record.stackTrace != null) {
        debugPrint('  ${record.stackTrace}');
      }
    } else {
      debugPrint(message);
    }
  });
}

class MonoChatApp extends StatelessWidget {
  const MonoChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, child) {
        final palette = themeController.palette;
        return CupertinoApp(
          title: 'MonoChat',
          theme: CupertinoThemeData(
            brightness: themeController.brightness,
            primaryColor: palette.primary,
            scaffoldBackgroundColor: palette.scaffoldBackground,
            barBackgroundColor: palette.barBackground,
            textTheme: CupertinoTextThemeData(
              primaryColor: palette.primary,
              textStyle: TextStyle(
                color: palette.text,
                fontFamily: '.SF Pro Text',
                fontSize: 17,
              ),
            ),
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(themeController.textScale),
              ),
              child: child!,
            );
          },
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the controller to decide which screen to show
    final state = context.select<AuthController, AuthState>((c) => c.state);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildScreen(state),
    );
  }

  Widget _buildScreen(AuthState state) {
    switch (state) {
      case AuthState.authenticated:
        return const HomeScreen();
      case AuthState.unauthenticated:
        return const LoginScreen();
      case AuthState.error:
        return const ErrorScreen();
      case AuthState.initializing:
        return const SplashScreen();
    }
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine the current theme brightness to select the splash image
    // Since AuthWrapper is inside Consumer<ThemeController>, we can just check brightness
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final splashImage = isDark
        ? 'assets/splash/splash_dark.png'
        : 'assets/splash/splash_light.png';

    return CupertinoPageScaffold(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Responsive image sizing
            SizedBox(
              width: 120,
              height: 120,
              child: Image.asset(splashImage, fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),
            const CupertinoActivityIndicator(),
          ],
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.select<AuthController, String?>(
      (c) => c.errorMessage,
    );

    return CupertinoPageScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: CupertinoColors.systemRed,
              ),
              const SizedBox(height: 16),
              Text(
                'Initialization Failed',
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              ),
              const SizedBox(height: 8),
              Text(error ?? 'Unknown error', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                child: const Text('Retry'),
                onPressed: () {
                  context.read<AuthController>().retry();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
