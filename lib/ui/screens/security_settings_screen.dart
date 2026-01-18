import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
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
                                      : 'Backup Not Active',
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
                                      : 'Enable cross-signing to backup your keys.',
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
                      if (!isEnabled) ...[
                        const SizedBox(height: 16),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 20,
                          ),
                          child: const Text('Bootstrap'),
                          onPressed: () => _bootstrap(context),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            // Privacy Toggles
            _buildToggleItem(context, 'Read Receipts', true, (v) {}),
            _buildToggleItem(context, 'Typing Indicators', true, (v) {}),
            _buildToggleItem(context, 'Send Crash Reports', false, (v) {}),
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
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Bootstrap'),
        content: const Text(
          'Implementation of secure backup bootstrap is pending.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }
}
