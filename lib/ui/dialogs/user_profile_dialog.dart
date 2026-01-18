import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:matrix/matrix.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/ui/widgets/presence_builder.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';
import 'package:monochat/ui/widgets/avatar_viewer.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';

/// iOS-styled user profile dialog.
///
/// Displays user information including:
/// - Avatar (tappable to view full size)
/// - Display name
/// - Matrix ID (tappable to copy)
/// - Presence status (online, last seen)
/// - Status message
/// - Actions (message, ignore)
class UserProfileDialog extends StatelessWidget {
  final Profile profile;
  final Client client;
  final Room? room; // Optional room context for room-specific actions

  const UserProfileDialog({
    super.key,
    required this.profile,
    required this.client,
    this.room,
  });

  /// Show the user profile dialog
  static Future<void> show({
    required BuildContext context,
    required Profile profile,
    required Client client,
    Room? room,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) =>
          UserProfileDialog(profile: profile, client: client, room: room),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final displayName =
        profile.displayName ?? profile.userId.localpart ?? l10n.unknownUser;
    final isOwnProfile = client.userID == profile.userId;
    final dmRoomId = client.getDirectChatFromUserId(profile.userId);

    return Container(
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 5,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            // Avatar
            _buildAvatar(context, palette),

            const Gap(16),

            // Display name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const Gap(8),

            // Matrix ID (tappable to copy)
            _buildMatrixId(context, palette),

            const Gap(12),

            // Presence status
            PresenceBuilder(
              userId: profile.userId,
              client: client,
              builder: (context, presence) {
                return _buildPresenceInfo(context, presence, palette);
              },
            ),

            const Gap(24),

            // Actions
            if (!isOwnProfile) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Message button
                    _buildActionButton(
                      context: context,
                      icon: CupertinoIcons.chat_bubble_fill,
                      label: dmRoomId == null
                          ? l10n.startConversation
                          : l10n.sendMessage,
                      color: palette.primary,
                      onTap: () => _startChat(context),
                    ),

                    const Gap(12),

                    // Ignore button
                    _buildActionButton(
                      context: context,
                      icon: CupertinoIcons.nosign,
                      label: l10n.ignoreUser,
                      color: CupertinoColors.systemRed,
                      isDestructive: true,
                      onTap: () => _ignoreUser(context),
                    ),
                  ],
                ),
              ),
            ],

            const Gap(16),

            // Close button
            CupertinoButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.close,
                style: TextStyle(color: palette.secondaryText),
              ),
            ),

            const Gap(8),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, palette) {
    final avatarUri = profile.avatarUrl;

    return GestureDetector(
      onTap: avatarUri != null
          ? () => _showAvatarFullScreen(context, avatarUri)
          : null,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.inputBackground,
          border: Border.all(color: palette.separator, width: 0.5),
        ),
        child: ClipOval(
          child: avatarUri != null
              ? MxcImage(
                  uri: avatarUri,
                  client: client,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                )
              : Center(
                  child: Text(
                    _getInitials(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                      color: palette.primary,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _getInitials() {
    final name = profile.displayName ?? profile.userId.localpart ?? '?';
    if (name.isEmpty) return '?';

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _showAvatarFullScreen(BuildContext context, Uri avatarUri) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => AvatarViewer(
          uri: avatarUri,
          client: client,
          displayName: profile.displayName ?? profile.userId,
        ),
      ),
    );
  }

  Widget _buildMatrixId(BuildContext context, palette) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: profile.userId));
        HapticFeedback.lightImpact();
        // Show feedback
        final overlay = Overlay.of(context);
        final entry = OverlayEntry(
          builder: (context) => Positioned(
            bottom: MediaQuery.of(context).size.height / 2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Copied!',
                  style: TextStyle(color: CupertinoColors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        );
        overlay.insert(entry);
        Future.delayed(const Duration(seconds: 1), () => entry.remove());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.inputBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc_on_clipboard,
              size: 14,
              color: palette.secondaryText,
            ),
            const Gap(6),
            Text(
              profile.userId,
              style: TextStyle(fontSize: 13, color: palette.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceInfo(
    BuildContext context,
    CachedPresence? presence,
    palette,
  ) {
    if (presence == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    String statusText;
    Color statusColor;

    if (presence.currentlyActive == true) {
      statusText = l10n.online;
      statusColor = CupertinoColors.activeGreen;
    } else if (presence.lastActiveTimestamp != null) {
      final lastSeen = presence.lastActiveTimestamp!;
      final now = DateTime.now();
      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 5) {
        statusText = l10n.justNow;
        statusColor = CupertinoColors.activeGreen.withValues(alpha: 0.7);
      } else if (diff.inHours < 1) {
        statusText = l10n.lastSeenMinutesAgo(diff.inMinutes);
        statusColor = CupertinoColors.systemGrey;
      } else if (diff.inHours < 24) {
        statusText = l10n.lastSeenHoursAgo(diff.inHours);
        statusColor = CupertinoColors.systemGrey;
      } else {
        statusText = l10n.lastSeenAt(DateFormat('MMM d').format(lastSeen));
        statusColor = CupertinoColors.systemGrey;
      }
    } else {
      statusText = l10n.offline;
      statusColor = CupertinoColors.systemGrey;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const Gap(6),
            Text(
              statusText,
              style: TextStyle(fontSize: 13, color: statusColor),
            ),
          ],
        ),
        // Status message
        if (presence.statusMsg != null && presence.statusMsg!.isNotEmpty) ...[
          const Gap(8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              presence.statusMsg!,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: palette.secondaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive ? color.withValues(alpha: 0.1) : color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isDestructive ? color : CupertinoColors.white,
            ),
            const Gap(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDestructive ? color : CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChat(BuildContext context) async {
    Navigator.pop(context);

    try {
      final existingDmId = client.getDirectChatFromUserId(profile.userId);

      // Get or create room ID
      final _ = existingDmId ?? await client.startDirectChat(profile.userId);

      // TODO: Navigate to chat using your navigation system
      // Example: Navigator.push(context, CupertinoPageRoute(builder: (_) => ChatScreen(roomId: roomId)));
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _ignoreUser(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.ignoreUser),
        content: Text(
          l10n.ignoreUserConfirmation(profile.displayName ?? profile.userId),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(l10n.ignore),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await client.ignoreUser(profile.userId);
        if (context.mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          showCupertinoDialog<void>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Error'),
              content: Text(e.toString()),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    }
  }
}

// internal class removed
