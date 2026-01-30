import 'dart:async';
import 'dart:io'; // For Platform check

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For some material icons fallback if needed, or theme helpers
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gap/gap.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/widgets/key_verification_dialog.dart';
import 'package:monochat/ui/widgets/toast.dart';
import 'package:provider/provider.dart';

class BootstrapDialog extends StatefulWidget {
  final Client client;
  final bool wipe;

  const BootstrapDialog({super.key, required this.client, this.wipe = false});

  @override
  State<BootstrapDialog> createState() => _BootstrapDialogState();
}

class _BootstrapDialogState extends State<BootstrapDialog> {
  final TextEditingController _recoveryKeyTextEditingController =
      TextEditingController();

  Bootstrap? bootstrap;

  String? _recoveryKeyInputError;
  bool _recoveryKeyInputLoading = false;
  String? titleText;
  bool _recoveryKeyStored = false;
  bool _recoveryKeyCopied = false;
  bool _storeInSecureStorage = false;
  bool? _wipe;

  String get _secureStorageKey => 'ssss_recovery_key_${widget.client.userID}';

  bool get _supportsSecureStorage =>
      Platform.isIOS ||
      Platform.isAndroid ||
      Platform.isMacOS ||
      Platform.isWindows ||
      Platform.isLinux;
  // Basically all platforms MonoChat runs on should support it, but checks depend on flutter_secure_storage support.

  String _getSecureStorageLocalizedName(BuildContext context) {
    // Assuming we added these strings to l10n
    final l10n = AppLocalizations.of(context)!;
    if (Platform.isAndroid) return l10n.storeInAndroidKeystore;
    if (Platform.isIOS || Platform.isMacOS) return l10n.storeInAppleKeyChain;
    return l10n.storeSecurlyOnThisDevice;
  }

  StreamSubscription<UiaRequest>? _uiaSubscription;
  String? _cachedPassword;

  @override
  void initState() {
    super.initState();
    // Temporarily handle UIA for this session
    _uiaSubscription = widget.client.onUiaRequest.stream.listen(
      _uiaRequestHandler,
    );
    _createBootstrap(widget.wipe);
  }

  @override
  void dispose() {
    _uiaSubscription?.cancel();
    _recoveryKeyTextEditingController.dispose();
    super.dispose();
  }

  Future<void> _uiaRequestHandler(UiaRequest request) async {
    if (!mounted) {
      // If dialog is closed, we can't handle UIA.
      try {
        request.cancel();
      } catch (e) {
        debugPrint('Error cancelling UIA (unmounted): $e');
      }
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    // Check if we can handle via password
    if (request.nextStages.contains(AuthenticationTypes.password)) {
      // Analyze error from previous attempt if any
      final errorMsg = request.error?.toString();
      final isInvalidPassword =
          errorMsg != null &&
          (errorMsg.contains('403') ||
              errorMsg.contains('Invalid password') ||
              errorMsg.contains('Forbidden'));

      // If we have an error, our cached password was wrong (or session expired).
      if (isInvalidPassword || request.error != null) {
        _cachedPassword = null;
      }

      // Try to use cached password if available and NO error
      if (_cachedPassword != null && request.error == null) {
        try {
          await request.completeStage(
            AuthenticationPassword(
              session: request.session,
              password: _cachedPassword!,
              identifier: AuthenticationUserIdentifier(
                user: widget.client.userID!,
              ),
            ),
          );
          return;
        } catch (e) {
          debugPrint('Error completing UIA with cached password: $e');
          // If it fails with "Future already completed", we can't do anything, but we shouldn't crash.
          if (e.toString().contains('Future already completed')) {
            return;
          }
          // If it fails immediately, we'll likely get another UIA request with error,
          // or we can fall through to show dialog.
          _cachedPassword = null;
        }
      }

      final displayText = isInvalidPassword
          ? 'Invalid password. Please try again.'
          : (request.error != null
                ? 'Authentication failed: ${request.error}'
                : 'Please enter your account password to confirm.');

      final password = await _showPasswordDialog(
        l10n,
        displayText,
        isError: isInvalidPassword || request.error != null,
      );

      if (!mounted) {
        try {
          request.cancel();
        } catch (_) {}
        return;
      }

      if (password == null || password.isEmpty) {
        try {
          request.cancel();
        } catch (e) {
          debugPrint('Error cancelling UIA: $e');
        }
        return;
      }

      // Cache the password for subsequent requests in this session
      _cachedPassword = password;

      try {
        await request.completeStage(
          AuthenticationPassword(
            session: request.session,
            password: password,
            identifier: AuthenticationUserIdentifier(
              user: widget.client.userID!,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error completing UIA stage: $e');
      }
      return;
    }

    // Fallback for unsupported stages
    debugPrint('Unsupported UIA stage: ${request.nextStages}');
    try {
      request.cancel();
    } catch (e) {
      debugPrint('Error cancelling unsupported UIA: $e');
    }
  }

  Future<String?> _showPasswordDialog(
    AppLocalizations l10n,
    String message, {
    bool isError = false,
  }) async {
    final controller = TextEditingController();
    return showCupertinoDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Password Required'),
        content: Column(
          children: [
            Text(
              message,
              style: isError
                  ? const TextStyle(color: CupertinoColors.systemRed)
                  : null,
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Password',
              obscureText: true,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Confirm'),
            onPressed: () => Navigator.pop(ctx, controller.text),
          ),
        ],
      ),
    );
  }

  void _createBootstrap(bool wipe) async {
    try {
      final client = widget.client;
      // Ensure everything is loaded
      await client.roomsLoading;
      await client.accountDataLoading;
      await client.userDeviceKeysLoading;

      // Wait for first sync if prevBatch is null
      while (client.prevBatch == null) {
        await client.onSync.stream.first;
      }

      await client.updateUserDeviceKeys();

      _wipe = wipe;
      titleText = null;
      _recoveryKeyStored = false;

      if (!context.mounted) return;

      setState(() {
        bootstrap = client.encryption!.bootstrap(
          onUpdate: (_) {
            if (context.mounted) setState(() {});
          },
        );
      });

      final key = await const FlutterSecureStorage().read(
        key: _secureStorageKey,
      );
      if (key != null) {
        _recoveryKeyTextEditingController.text = key;
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Error initializing backup: $e');
        Navigator.of(context).pop(false);
      }
    }
  }

  void _cancelAction() {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.skipChatBackup),
        content: Text(l10n.skipChatBackupWarning),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _goBackAction(false);
            },
            child: Text(l10n.skip),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _goBackAction(bool success) {
    if (success) _decryptLastEvents();
    Navigator.pop(context, success);
  }

  /// Attempt to decrypt last events in rooms after key backup is restored
  void _decryptLastEvents() {
    final client = widget.client;
    for (final room in client.rooms) {
      final event = room.lastEvent;
      if (event != null &&
          event.type == EventTypes.Encrypted &&
          event.messageType == MessageTypes.BadEncrypted &&
          event.content['can_request_session'] == true) {
        final sessionId = event.content.tryGet<String>('session_id');
        final senderKey = event.content.tryGet<String>('sender_key');
        if (sessionId != null && senderKey != null) {
          room.client.encryption?.keyManager.maybeAutoRequest(
            room.id,
            sessionId,
            senderKey,
          );
        }
      }
    }
  }

  /// Start device verification to transfer keys from another device
  Future<void> _startDeviceTransfer() async {
    final client = widget.client;

    setState(() => _recoveryKeyInputLoading = true);

    try {
      await client.updateUserDeviceKeys();

      final userKeys = client.userDeviceKeys[client.userID!];
      if (userKeys == null) {
        throw Exception('User keys not found');
      }

      final request = await userKeys.startVerification();

      if (context.mounted) {
        final success = await KeyVerificationDialog.show(context, request);

        if (success == true && context.mounted) {
          // Wait for secrets to be received
          final allCached =
              await client.encryption!.keyManager.isCached() &&
              await client.encryption!.crossSigning.isCached();

          if (!allCached) {
            // Wait for the secrets to be stored
            await client.encryption!.ssss.onSecretStored.stream.first.timeout(
              const Duration(seconds: 30),
            );
          }

          if (context.mounted) {
            _goBackAction(true);
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _recoveryKeyInputError = e.toString();
          _recoveryKeyInputLoading = false;
        });
      }
    } finally {
      if (context.mounted) {
        setState(() => _recoveryKeyInputLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;
    final bootstrap = this.bootstrap;

    if (bootstrap == null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.loadingMessages),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () =>
                Navigator.pop(context, false), // Simple close if not started
            child: const Icon(CupertinoIcons.clear),
          ),
        ),
        child: Center(
          child: StreamBuilder(
            stream: widget.client.onSyncStatus.stream,
            builder: (context, snapshot) {
              final status = snapshot.data;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(),
                  const Gap(16),
                  Text(
                    status != null
                        ? 'Syncing... ${((status.progress ?? 0) * 100).toInt()}%'
                        : l10n.loadingPleaseWait,
                    style: TextStyle(color: palette.secondaryText),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    _wipe ??= widget.wipe;
    final buttons = <Widget>[];
    Widget body = const Center(child: CupertinoActivityIndicator());
    titleText = l10n.loadingPleaseWait;

    // Case 1: New Key Generated (User needs to save it)
    if (bootstrap.newSsssKey?.recoveryKey != null &&
        _recoveryKeyStored == false) {
      final key = bootstrap.newSsssKey!.recoveryKey!;
      titleText = l10n.recoveryKey;

      return CupertinoPageScaffold(
        backgroundColor: palette.scaffoldBackground,
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.recoveryKey),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _cancelAction,
            child: const Icon(CupertinoIcons.clear),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Icon(
                CupertinoIcons.lock_shield_fill,
                size: 64,
                color: palette.primary,
              ),
              const Gap(24),
              Text(
                l10n.chatBackupDescription,
                style: TextStyle(color: palette.text, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const Gap(32),

              // Key Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.separator),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        key,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 16,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.doc_on_clipboard),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: key));
                        Toast.show(context, 'Recovery key copied');
                      },
                    ),
                  ],
                ),
              ),

              const Gap(24),

              if (_supportsSecureStorage)
                _buildToggleItem(
                  context,
                  _getSecureStorageLocalizedName(context),
                  l10n.storeInSecureStorageDescription,
                  _storeInSecureStorage,
                  (v) => setState(() => _storeInSecureStorage = v),
                ),

              const Gap(16),

              _buildToggleItem(
                context,
                l10n.copyToClipboard,
                l10n.saveKeyManuallyDescription,
                _recoveryKeyCopied,
                (v) {
                  if (v) {
                    Clipboard.setData(ClipboardData(text: key));
                    Toast.show(context, 'Recovery key copied');
                  }
                  setState(() => _recoveryKeyCopied = true);
                },
                isToggle: false,
              ),

              const Gap(32),

              CupertinoButton.filled(
                onPressed: (_recoveryKeyCopied || _storeInSecureStorage)
                    ? () {
                        if (_storeInSecureStorage) {
                          const FlutterSecureStorage().write(
                            key: _secureStorageKey,
                            value: key,
                          );
                        }
                        setState(() => _recoveryKeyStored = true);
                      }
                    : null,
                child: Text(l10n.next),
              ),
            ],
          ),
        ),
      );
    }
    // Check bootstrap states
    else {
      switch (bootstrap.state) {
        case BootstrapState.loading:
          break;
        case BootstrapState.askWipeSsss:
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => bootstrap.wipeSsss(_wipe!),
          );
          break;
        case BootstrapState.askBadSsss:
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              bootstrap.ignoreBadSecrets(true);
            } catch (e) {
              if (mounted) Toast.show(context, e.toString());
            }
          });
          break;
        case BootstrapState.askUseExistingSsss:
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              bootstrap.useExistingSsss(!_wipe!);
            } catch (e) {
              if (mounted) Toast.show(context, e.toString());
            }
          });
          break;
        case BootstrapState.askUnlockSsss:
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              bootstrap.unlockedSsss();
            } catch (e) {
              if (context.mounted) Toast.show(context, e.toString());
            }
          });
          break;
        case BootstrapState.askNewSsss:
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              await bootstrap.newSsss();
            } catch (e) {
              if (context.mounted) Toast.show(context, e.toString());
            }
          });
          break;

        case BootstrapState.openExistingSsss:
          _recoveryKeyStored = true;
          return CupertinoPageScaffold(
            backgroundColor: palette.scaffoldBackground,
            navigationBar: CupertinoNavigationBar(
              middle: Text(l10n.setupChatBackup),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _cancelAction,
                child: const Icon(CupertinoIcons.clear),
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  Icon(
                    CupertinoIcons.lock_open_fill,
                    size: 64,
                    color: palette.primary,
                  ),
                  const Gap(24),
                  Text(
                    l10n.pleaseEnterRecoveryKeyDescription,
                    style: TextStyle(color: palette.text, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(32),

                  CupertinoTextField(
                    controller: _recoveryKeyTextEditingController,
                    placeholder: 'Es** **** **** ****',
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    style: TextStyle(color: palette.text),
                    enabled: !_recoveryKeyInputLoading,
                  ),

                  if (_recoveryKeyInputError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _recoveryKeyInputError!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ),

                  const Gap(24),

                  CupertinoButton.filled(
                    onPressed: _recoveryKeyInputLoading
                        ? null
                        : () async {
                            setState(() {
                              _recoveryKeyInputError = null;
                              _recoveryKeyInputLoading = true;
                            });
                            try {
                              final key = _recoveryKeyTextEditingController.text
                                  .trim();
                              if (key.isEmpty) {
                                setState(() {
                                  _recoveryKeyInputLoading = false;
                                });
                                return;
                              }
                              await bootstrap.newSsssKey!.unlock(
                                keyOrPassphrase: key,
                              );
                              await bootstrap.openExistingSsss();

                              if (bootstrap.encryption.crossSigning.enabled) {
                                await bootstrap.client.encryption!.crossSigning
                                    .selfSign(recoveryKey: key);
                              }
                            } on InvalidPassphraseException catch (_) {
                              setState(() {
                                _recoveryKeyInputError = l10n.wrongRecoveryKey;
                              });
                            } on FormatException catch (_) {
                              setState(() {
                                _recoveryKeyInputError = l10n.wrongRecoveryKey;
                              });
                            } catch (e) {
                              setState(() {
                                _recoveryKeyInputError = e.toString();
                              });
                            } finally {
                              if (mounted) {
                                setState(
                                  () => _recoveryKeyInputLoading = false,
                                );
                              }
                            }
                          },
                    child: _recoveryKeyInputLoading
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : Text(l10n.unlockOldMessages),
                  ),

                  const Gap(24),

                  Row(
                    children: [
                      Expanded(
                        child: Container(height: 1, color: palette.separator),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: palette.secondaryText),
                        ),
                      ),
                      Expanded(
                        child: Container(height: 1, color: palette.separator),
                      ),
                    ],
                  ),
                  const Gap(24),

                  // Transfer from another device button
                  CupertinoButton(
                    color: palette.primary.withValues(alpha: 0.1),
                    onPressed: _recoveryKeyInputLoading
                        ? null
                        : _startDeviceTransfer,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.device_phone_portrait,
                          color: palette.primary,
                          size: 20,
                        ),
                        const Gap(8),
                        Text(
                          l10n.transferFromAnotherDevice,
                          style: TextStyle(color: palette.primary),
                        ),
                      ],
                    ),
                  ),

                  const Gap(16),

                  CupertinoButton(
                    color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                    onPressed: _recoveryKeyInputLoading
                        ? null
                        : () {
                            showCupertinoDialog(
                              context: context,
                              builder: (ctx) => CupertinoAlertDialog(
                                title: Text(l10n.recoveryKeyLost),
                                content: Text(l10n.chatBackupWarning),
                                actions: [
                                  CupertinoDialogAction(
                                    isDestructiveAction: true,
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      setState(() => _createBootstrap(true));
                                    },
                                    child: Text(l10n.wipeChatBackup),
                                  ),
                                  CupertinoDialogAction(
                                    isDefaultAction: true,
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(l10n.cancel),
                                  ),
                                ],
                              ),
                            );
                          },
                    child: Text(
                      l10n.recoveryKeyLost,
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ),
                ],
              ),
            ),
          );

        case BootstrapState.askWipeCrossSigning:
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => bootstrap.wipeCrossSigning(_wipe!),
          );
          break;
        case BootstrapState.askSetupCrossSigning:
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              await bootstrap.askSetupCrossSigning(
                setupMasterKey: true,
                setupSelfSigningKey: true,
                setupUserSigningKey: true,
              );
            } catch (e) {
              if (context.mounted) Toast.show(context, e.toString());
            }
          });
          break;
        case BootstrapState.askWipeOnlineKeyBackup:
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              bootstrap.wipeOnlineKeyBackup(_wipe!);
            } catch (e) {
              if (context.mounted) Toast.show(context, e.toString());
            }
          });
          break;
        case BootstrapState.askSetupOnlineKeyBackup:
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              await bootstrap.askSetupOnlineKeyBackup(true);
            } catch (e) {
              if (context.mounted) Toast.show(context, e.toString());
            }
          });
          break;

        case BootstrapState.error:
          titleText = l10n.oopsSomethingWentWrong;
          body = const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: CupertinoColors.systemRed,
            size: 80,
          );
          buttons.add(
            CupertinoButton.filled(
              onPressed: () => _goBackAction(false),
              child: Text(l10n.close),
            ),
          );
          break;

        case BootstrapState.done:
          titleText = l10n.everythingReady;
          body = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: CupertinoColors.activeGreen,
                size: 100,
              ),
              const Gap(24),
              Text(
                l10n.yourChatBackupHasBeenSetUp,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.text, fontSize: 18),
              ),
            ],
          );
          buttons.add(
            CupertinoButton.filled(
              onPressed: () => _goBackAction(true),
              child: Text(l10n.close),
            ),
          );
          break;
      }
    }

    // Default return for other states (mostly loading/auto-transitioning)
    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(titleText ?? l10n.loadingPleaseWait),
        leading: CupertinoButton(
          // Always allow close? Or only when safe? Bootstrap logic handles safe close.
          padding: EdgeInsets.zero,
          onPressed: _cancelAction,
          child: const Icon(CupertinoIcons.clear),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Center(child: body)),
              ...buttons.map(
                (b) =>
                    Padding(padding: const EdgeInsets.only(top: 16), child: b),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isToggle = true,
  }) {
    final palette = context.watch<ThemeController>().palette;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isToggle)
              CupertinoSwitch(value: value, onChanged: onChanged)
            else
              Icon(
                value
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: value ? palette.primary : palette.secondaryText,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
