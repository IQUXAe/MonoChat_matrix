import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
// import 'package:matrix/encryption.dart'; // Sometimes needed for extension methods
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:monochat/ui/widgets/bootstrap_dialog.dart';
import 'package:provider/provider.dart';

class SecuritySettingsScreen extends StatefulWidget {
  final Client client;
  const SecuritySettingsScreen({super.key, required this.client});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Privacy & Security'),
        backgroundColor: palette.barBackground,
        border: null,
      ),
      backgroundColor: palette.scaffoldBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Cross Signing / Backup section
            FutureBuilder<bool>(
              future: Future.value(
                widget.client.encryption?.crossSigning.enabled ?? false,
              ),
              builder: (context, snapshot) {
                final isEnabled = snapshot.data ?? false;
                final hasRemoteBackup =
                    widget.client.accountData['m.secret_storage.default_key'] !=
                    null;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.inputBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isEnabled
                                ? CupertinoIcons.lock_shield_fill
                                : CupertinoIcons.exclamationmark_shield_fill,
                            color: isEnabled
                                ? CupertinoColors.activeGreen
                                : CupertinoColors.systemRed,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEnabled
                                      ? 'Secure Backup Active'
                                      : (hasRemoteBackup
                                            ? 'Restore Backup'
                                            : 'Backup Not Active'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: palette.text,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isEnabled
                                      ? 'Your keys are backed up safely.'
                                      : (hasRemoteBackup
                                            ? 'Restore messages from cloud backup.'
                                            : 'Enable cross-signing to backup your keys.'),
                                  style: TextStyle(
                                    color: palette.secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isEnabled)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Text(
                            'Reset Secure Backup',
                            style: TextStyle(color: CupertinoColors.systemRed),
                          ),
                          onPressed: () => _resetBackup(context),
                        )
                      else if (hasRemoteBackup)
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 20,
                          ),
                          child: const Text('Restore from Backup'),
                          onPressed: () => _bootstrap(context),
                        )
                      else
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 20,
                          ),
                          child: const Text('Bootstrap'),
                          onPressed: () => _bootstrap(context),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            // Privacy Toggles
            // Privacy Toggles
            _buildToggleItem(
              context,
              'Read Receipts',
              MatrixService().sendReadReceipts,
              (v) {
                setState(() {
                  MatrixService().setSendReadReceipts(v);
                });
              },
            ),
            _buildToggleItem(
              context,
              'Typing Indicators',
              MatrixService().sendTypingIndicators,
              (v) {
                setState(() {
                  MatrixService().setSendTypingIndicators(v);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(
    BuildContext context,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final palette = context.watch<ThemeController>().palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: palette.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 17, color: palette.text),
              ),
            ),
            CupertinoSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Future<void> _bootstrap(BuildContext context) async {
    // If not enabled or needs setup, show full bootstrap dialog
    // This handles both setup and restore
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BootstrapDialog(client: widget.client),
        fullscreenDialog: true,
      ),
    );
    setState(() {});
  }

  Future<void> _resetBackup(BuildContext context) async {
    // Show confirmation dialog before resetting
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reset Secure Backup?'),
        content: const Text(
          'This will delete your current backup and create a new one. You will lose access to old encrypted messages if you do not have the old recovery key.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reset'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;

    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BootstrapDialog(client: widget.client, wipe: true),
        fullscreenDialog: true,
      ),
    );
    setState(() {});
  }
}
