import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/ui/widgets/key_verification_dialog.dart';
import 'package:provider/provider.dart';

class UserVerificationScreen extends StatefulWidget {
  final Client client;
  final String userId;

  const UserVerificationScreen({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<UserVerificationScreen> createState() => _UserVerificationScreenState();
}

class _UserVerificationScreenState extends State<UserVerificationScreen> {
  List<DeviceKeys>? _devices;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      // Ensure we have the latest keys
      // await widget.client.downloadKeysForUsers([widget.userId]);

      final userKeys = widget.client.userDeviceKeys[widget.userId];
      if (mounted) {
        setState(() {
          _devices = userKeys?.deviceKeys.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Error handling if needed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Verify User'),
        backgroundColor: palette.barBackground,
        border: null,
      ),
      backgroundColor: palette.scaffoldBackground,
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Prominent Verification Button
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: () => _startUserVerification(context),
                      borderRadius: BorderRadius.circular(12),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.shield_fill, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Verify User Identity',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'User: ${widget.userId}',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),

                  if (_devices == null || _devices!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No devices found for this user.',
                          style: TextStyle(color: palette.secondaryText),
                        ),
                      ),
                    )
                  else
                    ..._devices!.map((device) {
                      return _buildDeviceItem(context, device);
                    }).toList(),
                ],
              ),
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, DeviceKeys device) {
    final palette = context.watch<ThemeController>().palette;
    final isVerified =
        device.verified; // DeviceKeys has checked verification status usually

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
                  device.deviceDisplayName ??
                      device.deviceId ??
                      'Unknown Device',
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

  Future<void> _startVerification(
    BuildContext context,
    DeviceKeys device,
  ) async {
    try {
      final request = await device.startVerification();

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

  Future<void> _startUserVerification(BuildContext context) async {
    try {
      final userKeys = widget.client.userDeviceKeys[widget.userId];
      if (userKeys == null) {
        throw Exception('User keys not found');
      }

      final request = await userKeys.startVerification();

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
