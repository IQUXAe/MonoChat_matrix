import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/widgets/avatar_viewer.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Profile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  void _refreshProfile() {
    final client = context.read<AuthController>().client;
    if (client != null) {
      _profileFuture = client.fetchOwnProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final themeController = context.watch<ThemeController>();
    final palette = themeController.palette;
    final client = authController.client;

    if (client == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      child: FutureBuilder<Profile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final displayName =
              profile?.displayName ?? client.userID?.localpart ?? 'User';
          final avatarUrl = profile?.avatarUrl;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Standard Navigation Bar for reliable navigation
              CupertinoSliverNavigationBar(
                largeTitle: Text(
                  AppLocalizations.of(context)?.profile ?? 'Profile',
                ),
                backgroundColor: palette.barBackground.withValues(alpha: 0.8),
                border: Border(
                  bottom: BorderSide(
                    color: palette.separator.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Edit'),
                  onPressed: () =>
                      _showEditProfileSheet(context, client, displayName),
                ),
              ),

              SliverToBoxAdapter(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Avatar Section
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            if (avatarUrl != null) {
                              showCupertinoModalPopup(
                                context: context,
                                builder: (context) => AvatarViewer(
                                  uri: avatarUrl,
                                  client: client,
                                  displayName: displayName,
                                ),
                              );
                            }
                          },
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.barBackground,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: MatrixAvatar(
                                  avatarUrl: avatarUrl,
                                  name: displayName,
                                  client: client,
                                  size: 100, // Standard size
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.activeBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: palette.scaffoldBackground,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.qrcode,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name & ID
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        client.userID ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: palette.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Stats
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildStatsSection(context, client, palette),
                      ),
                      const SizedBox(height: 32),

                      // Actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildActionSection(
                              palette,
                              title: 'ACCOUNT',
                              children: [
                                _ProfileActionTile(
                                  icon: CupertinoIcons.qrcode,
                                  iconColor: CupertinoColors.systemPurple,
                                  title: 'QR Code',
                                  onTap: () => _showQRCode(context, client),
                                  palette: palette,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildActionSection(
                              palette,
                              title: 'SESSION',
                              children: [
                                _ProfileActionTile(
                                  icon: CupertinoIcons.square_arrow_right,
                                  iconColor: CupertinoColors.systemRed,
                                  title: 'Sign Out',
                                  isDestructive: true,
                                  onTap: () => _showLogoutConfirmation(
                                    context,
                                    authController,
                                  ),
                                  palette: palette,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    Client client,
    dynamic palette,
  ) {
    final rooms = client.rooms;
    final directChats = rooms.where((r) => r.isDirectChat).length;
    final groupChats = rooms.length - directChats;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: palette.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            value: rooms.length.toString(),
            label: 'Total',
            palette: palette,
          ),
          Container(
            width: 1,
            height: 30,
            color: palette.separator.withValues(alpha: 0.5),
          ),
          _StatItem(
            value: directChats.toString(),
            label: 'Direct',
            palette: palette,
          ),
          Container(
            width: 1,
            height: 30,
            color: palette.separator.withValues(alpha: 0.5),
          ),
          _StatItem(
            value: groupChats.toString(),
            label: 'Groups',
            palette: palette,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(
    dynamic palette, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.secondaryText,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: palette.inputBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: palette.separator.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showQRCode(BuildContext context, Client client) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Your QR Code'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.qrcode,
                    size: 150,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                client.userID ?? '',
                style: const TextStyle(fontSize: 13, fontFamily: 'Monospace'),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(
    BuildContext context,
    AuthController controller,
  ) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? '
          'You will need to log in again to access your chats.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sign Out'),
            onPressed: () {
              Navigator.pop(context);
              controller.logout();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    Client client,
    String currentName,
  ) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) =>
          _EditProfileSheet(client: client, currentName: currentName),
    );
    setState(() {
      _profileFuture = client.fetchOwnProfile();
    });
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final dynamic palette;

  const _StatItem({
    required this.value,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: palette.text,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: palette.secondaryText),
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final dynamic palette;

  const _ProfileActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    required this.palette,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDestructive ? CupertinoColors.systemRed : iconColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  color: isDestructive
                      ? CupertinoColors.systemRed
                      : palette.text,
                ),
              ),
            ),
            if (!isDestructive)
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: palette.secondaryText.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final Client client;
  final String currentName;

  const _EditProfileSheet({required this.client, required this.currentName});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _displayNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final userId = widget.client.userID!;
      await widget.client.setProfileField(userId, 'displayname', {
        'displayname': _displayNameController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to update profile: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final palette = themeController.palette;

    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: palette.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          CupertinoTextField(
            controller: _displayNameController,
            placeholder: 'Display Name',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: palette.inputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: palette.text),
          ),
          const Spacer(),
          CupertinoButton.filled(
            onPressed: _isLoading ? null : _saveProfile,
            borderRadius: BorderRadius.circular(12),
            child: _isLoading
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
