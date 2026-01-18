import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/ui/widgets/key_verification_dialog.dart';
import 'package:provider/provider.dart';

/// Screen to list active sessions and verify them.
class DevicesScreen extends StatefulWidget {
  final Client client;
  const DevicesScreen({super.key, required this.client});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Devices'),
        backgroundColor: palette.barBackground,
        border: null,
      ),
      backgroundColor: palette.scaffoldBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 4),
              child: Text(
                'ACTIVE SESSIONS',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_devices == null)
              const Center(child: CupertinoActivityIndicator())
            else if (_devices!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No other devices found.',
                    style: TextStyle(color: palette.secondaryText),
                  ),
                ),
              )
            else
              ..._devices!.map((device) {
                if (device.deviceId == widget.client.deviceID)
                  return const SizedBox();
                if (device.deviceId == null) return const SizedBox();

                // Display current status.
                // Note: Real verification status check requires looking up DeviceKeys.
                // We simplified this previously to assume false unless checked.
                // Here we could try to check properly if desired, but for now we re-use previous logic.

                return _buildDeviceItem(context, device);
              }).toList(),

            const SizedBox(height: 24),
            if (_devices != null && _devices!.isNotEmpty)
              const Center(
                child: Text(
                  'Tap "Verify" to compare emojis and ensure your session is secure.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, Device device) {
    final palette = context.watch<ThemeController>().palette;
    final myUserId = widget.client.userID;
    final deviceKeys = myUserId != null
        ? widget.client.userDeviceKeys[myUserId]?.deviceKeys[device.deviceId]
        : null;
    final isVerified = deviceKeys?.verified ?? false;

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
                : CupertinoIcons.lock_shield,
            size: 28,
            color: isVerified
                ? CupertinoColors.activeGreen
                : CupertinoColors.systemRed,
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
          if (isVerified)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Text(
                'Verified',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.activeGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startVerification(BuildContext context, Device device) async {
    try {
      final userDeviceKeys =
          widget.client.userDeviceKeys[widget.client.userID!];
      if (userDeviceKeys == null) {
        throw Exception('User keys not available. Please try again later.');
      }

      final deviceKeys = userDeviceKeys.deviceKeys[device.deviceId];
      if (deviceKeys == null) {
        throw Exception('Device keys not found for ${device.deviceId}.');
      }

      final request = await deviceKeys.startVerification();

      if (mounted) {
        await KeyVerificationDialog.show(context, request);
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
