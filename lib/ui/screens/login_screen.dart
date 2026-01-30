import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:provider/provider.dart';
import '../theme/app_palette.dart';

/// Login flow:
/// 1. HomeserverPickerScreen - enter homeserver, check it
/// 2. LoginCredentialsScreen - enter username/password OR use SSO

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Current step: 0 = homeserver picker, 1 = credentials
  int _step = 0;

  final _homeserverController = TextEditingController(text: 'matrix.org');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _showPassword = false;
  String? _checkedHomeserver;

  // SSO support
  List<LoginFlow>? _loginFlows;
  bool get _supportsSso =>
      _loginFlows?.any((f) => f.type == 'm.login.sso') ?? false;
  bool get _supportsPassword =>
      _loginFlows?.any((f) => f.type == 'm.login.password') ?? false;

  @override
  void dispose() {
    _homeserverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Step 1: Check homeserver and get login flows
  Future<void> _checkHomeserver() async {
    var homeserver = _homeserverController.text.trim().toLowerCase();
    if (homeserver.isEmpty) {
      setState(() => _error = 'Please enter a homeserver');
      return;
    }

    // Add https:// if not present
    if (!homeserver.startsWith('http://') &&
        !homeserver.startsWith('https://')) {
      homeserver = 'https://$homeserver';
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _loginFlows = null;
    });

    try {
      final uri = Uri.parse(homeserver);
      if (uri.host.isEmpty) {
        throw Exception('Invalid homeserver URL');
      }

      // Check homeserver and get login flows using main client
      final client = MatrixService().client;
      if (client != null) {
        final (_, _, loginFlows, _) = await client.checkHomeserver(uri);
        _loginFlows = loginFlows;
      }

      // Success - proceed to step 2
      setState(() {
        _checkedHomeserver = homeserver;
        _step = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error =
            'Could not connect: ${e.toString().replaceAll('Exception: ', '')}';
        _isLoading = false;
      });
    }
  }

  /// SSO Login
  Future<void> _loginWithSso() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = MatrixService().client;
      if (client == null) throw Exception('Client not initialized');

      // Determine platform support (Mobile/Web/macOS are "default", others need localhost)
      final isDefaultPlatform =
          Platform.isIOS || Platform.isAndroid || Platform.isMacOS || kIsWeb;

      // Build redirect URL
      final redirectUrl = kIsWeb
          ? Uri.base.resolve('auth.html').toString()
          : isDefaultPlatform
          ? 'monochat://login'
          : 'http://localhost:3001/login';

      final ssoUrl = client.homeserver!.replace(
        path: '/_matrix/client/v3/login/sso/redirect',
        queryParameters: {'redirectUrl': redirectUrl},
      );

      // Open SSO in browser with a waiting dialog
      // On desktop (Linux/Windows), we use the system browser with localhost redirect
      final useWebview = Platform.isIOS || Platform.isAndroid;

      final callbackUrlScheme = isDefaultPlatform
          ? 'monochat'
          : 'http://localhost:3001';

      // Control flag for cancellation
      var isCancelled = false;

      // Logic to show dialog and wait for result or cancellation
      Future<String?> showWaitingDialog() {
        return showCupertinoDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Waiting for Login'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Column(
                children: [
                  Text('Please complete login in your browser...'),
                  SizedBox(height: 12),
                  CupertinoActivityIndicator(),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Cancel'),
                onPressed: () {
                  isCancelled = true;
                  Navigator.pop(context, 'cancel');
                },
              ),
            ],
          ),
        );
      }

      // Start authentication task
      final authTask = FlutterWebAuth2.authenticate(
        url: ssoUrl.toString(),
        callbackUrlScheme: callbackUrlScheme,
        options: FlutterWebAuth2Options(useWebview: useWebview),
      );

      // Run dialog and auth in parallel.
      // We want to wait for auth, but allow dialog to cancel us.
      // Since we can't externally cancel `authTask`, we just ignore its result if cancelled.

      // We start the dialog. It stays open until:
      // A) User clicks cancel (returns 'cancel')
      // B) Auth finishes successfully (we pop it programmatically)

      final dialogFuture = showWaitingDialog();

      // Race!
      // Actually, we can't race easily because dialogFuture blocks until interaction,
      // but we want to pop it when authTask finishes.

      String? result;

      try {
        // Create a future that completes when auth finishes, then pops dialog
        final authWithPopup = authTask.then((res) {
          if (!isCancelled && mounted) {
            Navigator.of(context).pop(); // Close waiting dialog
          }
          return res;
        });

        // Wait for either dialog cancellation (user pressed button) OR auth success (which auto-pops dialog)
        // Note: If auth finishes, `authWithPopup` pops the dialog, so `dialogFuture` completes too.
        // If user cancels, `dialogFuture` completes with 'cancel'. `authTask` continues in background but satisfied.

        await Future.any([authWithPopup, dialogFuture]);

        if (isCancelled) {
          throw Exception('Login cancelled by user');
        }

        // If we are here, auth finished or dialog finished.
        // If auth finished, `result` comes from authTask.
        // We need the result.
        result = await authTask;
      } catch (e) {
        if (isCancelled) {
          // User explicitly cancelled via dialog - reset UI but show no error
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _error = _getFriendlyErrorMessage(e);
            _isLoading = false;
          });
        }
      }

      if (result == null) throw Exception('No auth result');

      // Extract login token
      final token = Uri.parse(result).queryParameters['loginToken'];
      if (token == null || token.isEmpty) {
        throw Exception('No login token received');
      }

      // Login with token
      await client.login(
        LoginType.mLoginToken,
        token: token,
        initialDeviceDisplayName: 'MonoChat ${Platform.operatingSystem}',
      );

      if (mounted) {
        // Notify auth controller
        context.read<AuthController>().notifyLoggedIn();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // If we are here, it means login token exchange failed
          _error = _getFriendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  String _getFriendlyErrorMessage(Object error) {
    final str = error.toString();
    if (str.contains('cancelled') || str.contains('CANCELED')) {
      return 'Login cancelled.';
    }
    if (str.contains('SocketException') ||
        str.contains('Network is unreachable')) {
      return 'Network error. Please check your internet connection.';
    }
    if (str.contains('403')) {
      return 'Invalid credentials or access denied.';
    }
    if (str.contains('No login token')) {
      return 'Login failed. Could not retrieve session token.';
    }

    // Clean up generic "Exception:" prefix
    return str.replaceAll('Exception: ', '');
  }

  /// Password Login
  Future<void> _loginWithPassword() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your username');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authController = context.read<AuthController>();
      await authController.login(
        _usernameController.text.trim(),
        _passwordController.text,
        _checkedHomeserver!,
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    setState(() {
      _step = 0;
      _error = null;
      _loginFlows = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    // Determine if dark based on actual background color luminance
    final bgLuminance = palette.scaffoldBackground.computeLuminance();
    final effectiveIsDark = bgLuminance < 0.5;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: _step == 1
          ? CupertinoNavigationBar(
              backgroundColor: palette.barBackground,
              border: null,
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _goBack,
                child: const Icon(CupertinoIcons.back),
              ),
              middle: Text(
                'Sign In to ${_checkedHomeserver?.replaceAll('https://', '')}',
                style: TextStyle(color: palette.text, fontSize: 16),
              ),
            )
          : null,
      child: SafeArea(
        child: _step == 0
            ? _buildHomeserverPicker(palette, effectiveIsDark)
            : _buildCredentialsForm(palette, effectiveIsDark),
      ),
    );
  }

  /// Step 1: Homeserver Picker
  Widget _buildHomeserverPicker(AppPalette palette, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Spacer(),

                    // Logo/Splash Image
                    Hero(
                      tag: 'app-logo',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          isDark
                              ? 'assets/splash/splash_dark.png'
                              : 'assets/splash/splash_light.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const Gap(20),

                    Text(
                      'MonoChat',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                        color: palette.text,
                      ),
                    ),

                    const Gap(8),

                    Text(
                      'Secure messaging with Matrix',
                      style: TextStyle(
                        fontSize: 15,
                        color: palette.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(),

                    // Error message
                    if (_error != null) _buildErrorMessage(_error!, palette),

                    // Homeserver field
                    _buildTextField(
                      controller: _homeserverController,
                      placeholder: 'matrix.org',
                      label: 'Sign in with:',
                      icon: CupertinoIcons.globe,
                      palette: palette,
                      keyboardType: TextInputType.url,
                      enabled: !_isLoading,
                    ),

                    const Gap(24),

                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _isLoading ? null : _checkHomeserver,
                        child: _isLoading
                            ? const CupertinoActivityIndicator()
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17,
                                  color: CupertinoColors
                                      .white, // FIX: Enforce white text
                                ),
                              ),
                      ),
                    ),

                    const Gap(16),

                    // Help text
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showHomeserverHelp,
                      child: Text(
                        'What is a homeserver?',
                        style: TextStyle(fontSize: 14, color: palette.primary),
                      ),
                    ),

                    const Gap(24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Step 2: Credentials Form with SSO option
  Widget _buildCredentialsForm(AppPalette palette, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Gap(20),

                    // Small logo
                    Hero(
                      tag: 'app-logo',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          isDark
                              ? 'assets/splash/splash_dark.png'
                              : 'assets/splash/splash_light.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const Gap(24),

                    // Error message
                    if (_error != null) _buildErrorMessage(_error!, palette),

                    // SSO Button (if supported)
                    if (_supportsSso) ...[
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _isLoading ? null : _loginWithSso,
                          child: _isLoading
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.globe,
                                      size: 20,
                                      color: CupertinoColors.white,
                                    ),
                                    Gap(8),
                                    Text(
                                      'Continue with SSO',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 17,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      if (_supportsPassword) ...[
                        const Gap(20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 0.5,
                                color: palette.separator,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'or',
                                style: TextStyle(color: palette.secondaryText),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 0.5,
                                color: palette.separator,
                              ),
                            ),
                          ],
                        ),
                        const Gap(20),
                      ],
                    ],

                    // Password login (if supported)
                    if (_supportsPassword || _loginFlows == null) ...[
                      // Username field
                      _buildTextField(
                        controller: _usernameController,
                        placeholder: '@username:domain or email',
                        label: 'Username or Email',
                        icon: CupertinoIcons.person,
                        palette: palette,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        autofocus: !_supportsSso,
                      ),

                      const Gap(16),

                      // Password field
                      _buildTextField(
                        controller: _passwordController,
                        placeholder: 'Password',
                        label: 'Password',
                        icon: CupertinoIcons.lock,
                        palette: palette,
                        obscureText: !_showPassword,
                        enabled: !_isLoading,
                        suffix: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          minimumSize: const Size(0, 0),
                          child: Icon(
                            _showPassword
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
                            size: 20,
                            color: palette.secondaryText,
                          ),
                        ),
                        onSubmitted: (_) => _loginWithPassword(),
                      ),

                      const Spacer(),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _isLoading ? null : _loginWithPassword,
                          child: _isLoading
                              ? const CupertinoActivityIndicator()
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 17,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                        ),
                      ),

                      const Gap(16),

                      // Forgot password
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          // TODO: Implement password reset
                        },
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemRed,
                          ),
                        ),
                      ),
                    ],

                    // SSO only - show spacer
                    if (_supportsSso && !_supportsPassword) const Spacer(),

                    const Gap(24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorMessage(String error, palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemRed,
            size: 20,
          ),
          const Gap(12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    String? label,
    required IconData icon,
    required palette,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
    bool enabled = true,
    bool autofocus = false,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: palette.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.separator.withValues(alpha: 0.5)),
          ),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscureText,
            keyboardType: keyboardType,
            enabled: enabled,
            autofocus: autofocus,
            onSubmitted: onSubmitted,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(icon, size: 20, color: palette.secondaryText),
            ),
            suffix: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffix,
                  )
                : null,
            style: TextStyle(color: palette.text, fontSize: 16),
            placeholderStyle: TextStyle(color: palette.secondaryText),
          ),
        ),
      ],
    );
  }

  void _showHomeserverHelp() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('What is a homeserver?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'A homeserver is a Matrix server that stores your account and messages. '
            'You can use any public server like matrix.org, or run your own.\n\n'
            'Your Matrix ID will be @username:homeserver.com',
            textAlign: TextAlign.left,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Got it'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
