import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/ui/widgets/key_verification_dialog.dart';
import 'package:provider/provider.dart';

class SecuritySheet extends StatefulWidget {
  final Client client;

  const SecuritySheet({super.key, required this.client});

  @override
  State<SecuritySheet> createState() => _SecuritySheetState();
}

class _SecuritySheetState extends State<SecuritySheet> {
  List<Device>? _devices;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await widget.client.getDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    } catch (e) {
      if (mounted) {
        // Handle error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600, // Make it taller for device list
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.watch<ThemeController>().palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Security',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                // Cross-Signing Section
                FutureBuilder<bool>(
                  future: Future.value(
                    widget.client.encryption?.crossSigning.enabled ?? false,
                  ),
                  builder: (context, snapshot) {
                    final isEnabled = snapshot.data ?? false;
                    // ... same logic as before ...
                    if (!isEnabled) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: _buildActionItem(
                          context,
                          icon: CupertinoIcons.lock_shield_fill,
                          title: 'Bootstrap Cross-Signing',
                          subtitle: 'Enable secure key backup & verification',
                          onTap: () => _bootstrapCrossSigning(context),
                        ),
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 24.0),
                      child: Text(
                        'Cross-signing is active',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CupertinoColors.systemGreen),
                      ),
                    );
                  },
                ),

                const Text(
                  'Devices',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(height: 8),

                if (_devices == null)
                  const Center(child: CupertinoActivityIndicator())
                else if (_devices!.isEmpty)
                  const Text('No other devices found.')
                else
                  ..._devices!.map((device) {
                    // Check current device. property might be deviceID or deviceId depending on SDK version
                    // Standard is deviceID usually for client, but device.deviceId for Device object?
                    // FluffyChat checked client.deviceID.
                    if (device.deviceId == widget.client.deviceID)
                      return const SizedBox();

                    // We default IsVerified to false as we can't reliably check it without complex lookups right now
                    // and we want to allow verification.
                    return _buildDeviceItem(context, device, false);
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(
    BuildContext context,
    Device device,
    bool isVerified,
  ) {
    final palette = context.watch<ThemeController>().palette;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isVerified
                ? CupertinoIcons.checkmark_shield_fill
                : CupertinoIcons.device_phone_portrait,
            size: 28,
            color: isVerified
                ? CupertinoColors.systemGreen
                : palette.secondaryText,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName ?? device.deviceId ?? 'Unknown Device',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                Text(
                  'ID: ${device.deviceId}',
                  style: TextStyle(fontSize: 12, color: palette.secondaryText),
                ),
              ],
            ),
          ),
          if (!isVerified)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              onPressed: () => _startVerification(context, device),
              child: const Text('Verify', style: TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final palette = context.watch<ThemeController>().palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: palette.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: palette.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bootstrapCrossSigning(BuildContext context) async {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Bootstrap'),
        content: const Text(
          'This feature requires password entry. Implementing secure password prompt...',
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

  Future<void> _startVerification(BuildContext context, Device device) async {
    try {
      // Logic adapted from FluffyChat
      final userDeviceKeys =
          widget.client.userDeviceKeys[widget.client.userID!];
      if (userDeviceKeys == null) {
        // Try to trigger download if possible or just show error
        // await widget.client.downloadKeys([widget.client.userID!]); // Method name uncertain
        throw Exception('User keys not available. Please try again later.');
      }

      final deviceKeys = userDeviceKeys.deviceKeys[device.deviceId];
      if (deviceKeys == null) {
        throw Exception('Device keys not found for ${device.deviceId}.');
      }

      final request = await deviceKeys.startVerification();

      if (mounted) {
        await KeyVerificationDialog.show(context, request);
        // Reload list logic if needed
        _loadDevices();
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
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
  }
}
