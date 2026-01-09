import 'package:flutter/cupertino.dart';

import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';

// =============================================================================
// PROFILE SCREEN
// =============================================================================

/// User profile screen with account information and actions.
///
/// Displays:
/// - User avatar and display name
/// - Matrix ID
/// - Account statistics
/// - Account actions (edit profile, logout)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final client = authController.client;

    if (client == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: context.watch<ThemeController>().palette.barBackground,
      child: CustomScrollView(
        slivers: [
          // Navigation bar
          CupertinoSliverNavigationBar(
            largeTitle: Text(_getLocalizedTitle(context)),
            backgroundColor: context
                .watch<ThemeController>()
                .palette
                .barBackground,
            border: null,
          ),

          // Profile content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Profile Card
                  _ProfileCard(client: client),

                  const SizedBox(height: 24),

                  // Stats Section
                  _buildStatsSection(context, client),

                  const SizedBox(height: 24),

                  // Actions Section
                  _buildActionsSection(context, client),

                  const SizedBox(height: 24),

                  // Danger Zone
                  _buildDangerZone(context, authController),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedTitle(BuildContext context) {
    return AppLocalizations.of(context)?.profile ?? 'Profile';
  }

  Widget _buildStatsSection(BuildContext context, Client client) {
    final rooms = client.rooms;
    final directChats = rooms.where((r) => r.isDirectChat).length;
    final groupChats = rooms.length - directChats;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.watch<ThemeController>().palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            value: rooms.length.toString(),
            label: 'Total Chats',
            icon: CupertinoIcons.chat_bubble_2_fill,
            color: CupertinoColors.activeBlue,
          ),
          _StatDivider(),
          _StatItem(
            value: directChats.toString(),
            label: 'Direct',
            icon: CupertinoIcons.person_fill,
            color: CupertinoColors.systemGreen,
          ),
          _StatDivider(),
          _StatItem(
            value: groupChats.toString(),
            label: 'Groups',
            icon: CupertinoIcons.person_3_fill,
            color: CupertinoColors.systemOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, Client client) {
    return Container(
      decoration: BoxDecoration(
        color: context.watch<ThemeController>().palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _ProfileActionTile(
            icon: CupertinoIcons.qrcode,
            iconColor: CupertinoColors.systemPurple,
            title: 'QR Code',
            subtitle: 'Share your profile',
            onTap: () => _showQRCode(context, client),
          ),
          _buildDivider(context),
          _ProfileActionTile(
            icon: CupertinoIcons.device_phone_portrait,
            iconColor: CupertinoColors.systemBlue,
            title: 'Devices',
            subtitle: 'Manage your sessions',
            onTap: () {},
          ),
          _buildDivider(context),
          _ProfileActionTile(
            icon: CupertinoIcons.shield_fill,
            iconColor: CupertinoColors.systemGreen,
            title: 'Security',
            subtitle: 'Encryption keys & verification',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context, AuthController controller) {
    return Container(
      decoration: BoxDecoration(
        color: context.watch<ThemeController>().palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _ProfileActionTile(
        icon: CupertinoIcons.square_arrow_right,
        iconColor: CupertinoColors.systemRed,
        title: 'Sign Out',
        subtitle: 'Log out of your account',
        isDestructive: true,
        onTap: () => _showLogoutConfirmation(context, controller),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(
        height: 0.5,
        color: context.read<ThemeController>().palette.separator,
      ),
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
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.qrcode,
                    size: 100,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(client.userID ?? '', style: const TextStyle(fontSize: 13)),
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
}

// =============================================================================
// PROFILE CARD
// =============================================================================

/// Profile card with avatar and user info.
class _ProfileCard extends StatelessWidget {
  final Client client;

  const _ProfileCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.watch<ThemeController>().palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          // Check if user is logged in
          if (client.userID == null) {
            return Column(
              children: [
                MatrixAvatar(
                  avatarUrl: null,
                  name: 'User',
                  client: client,
                  size: 100,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Not logged in',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ],
            );
          }

          return FutureBuilder<Profile>(
            future: client.fetchOwnProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final displayName =
                  profile?.displayName ?? client.userID?.localpart ?? 'User';

              return Column(
                children: [
                  // Avatar with edit button
                  Stack(
                    children: [
                      MatrixAvatar(
                        avatarUrl: profile?.avatarUrl,
                        name: displayName,
                        client: client,
                        size: 100,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => _showEditAvatarSheet(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context
                                    .watch<ThemeController>()
                                    .palette
                                    .scaffoldBackground,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.camera_fill,
                              size: 16,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Display name
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Matrix ID
                  Text(
                    client.userID ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      color: context
                          .watch<ThemeController>()
                          .palette
                          .secondaryText,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Edit Profile button
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 10,
                    ),
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                    onPressed: () => _showEditProfileSheet(context),
                    child: Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: context.watch<ThemeController>().palette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEditAvatarSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Choose from Library'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Remove Photo'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _EditProfileSheet(client: client),
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

/// Statistics item widget.
class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.watch<ThemeController>().palette.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical divider for stats.
class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 50,
      color: context.watch<ThemeController>().palette.separator,
    );
  }
}

/// Profile action tile.
class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: isDestructive
                          ? CupertinoColors.systemRed
                          : context.watch<ThemeController>().palette.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context
                          .watch<ThemeController>()
                          .palette
                          .secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: context.watch<ThemeController>().palette.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// EDIT PROFILE SHEET
// =============================================================================

/// Bottom sheet for editing profile.
class _EditProfileSheet extends StatefulWidget {
  final Client client;

  const _EditProfileSheet({required this.client});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _displayNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.client.fetchOwnProfile();
      _displayNameController.text = profile.displayName ?? '';
    } catch (_) {}
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      // Use the Matrix API to set display name via profile field
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
    return Container(
      height: 300,
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

          // Title
          const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Display Name
          CupertinoTextField(
            controller: _displayNameController,
            placeholder: 'Display Name',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.watch<ThemeController>().palette.inputBackground,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const Spacer(),

          // Save button
          CupertinoButton.filled(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
