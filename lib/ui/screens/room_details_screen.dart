import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/core/utils/date_formats.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/dialogs/user_profile_dialog.dart';
import 'package:monochat/ui/screens/user_verification_screen.dart';
import 'package:monochat/ui/widgets/avatar_viewer.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';
import 'package:monochat/ui/widgets/presence_builder.dart';
import 'package:provider/provider.dart';
import '../theme/app_palette.dart';
import 'package:monochat/ui/screens/settings/access_and_visibility_screen.dart';
import 'package:monochat/ui/screens/settings/chat_permissions_screen.dart';
import 'room_members_screen.dart';

// ... (existing imports will be preserved by using correct target range, but I need to be careful with replace_file_content and imports)
// Actually, I should use multi_replace to handle import and widget addition separately cleanly.
// Let's use replace_file_content for imports at top, then another for the body.
// WAIT, I can just use one multi_replace.

/// Full-page room/chat details screen.
class RoomDetailsScreen extends StatefulWidget {
  final Room room;
  final Client client;

  const RoomDetailsScreen({
    super.key,
    required this.room,
    required this.client,
  });

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  List<User>? _members;
  bool _loadingMembers = true;

  // Media counts
  int _photoCount = 0;
  int _videoCount = 0;
  int _audioCount = 0;
  int _linkCount = 0;
  int _fileCount = 0;
  bool _loadingMedia = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadMediaCounts();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.room.requestParticipants();
      if (mounted) {
        setState(() {
          _members = members
            ..sort((a, b) => b.powerLevel.compareTo(a.powerLevel));
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadMediaCounts() async {
    try {
      final timeline = await widget.room.getTimeline();

      // Request more history to get accurate counts
      var attempts = 0;
      while (timeline.canRequestHistory && attempts < 3) {
        await timeline.requestHistory(historyCount: 100);
        attempts++;
      }

      var photos = 0, videos = 0, audios = 0, links = 0, files = 0;

      for (final event in timeline.events) {
        if (event.type != EventTypes.Message) continue;

        final msgType = event.messageType;
        if (msgType == MessageTypes.Image) {
          photos++;
        } else if (msgType == MessageTypes.Video) {
          videos++;
        } else if (msgType == MessageTypes.Audio) {
          audios++;
        } else if (msgType == MessageTypes.File) {
          files++;
        } else if (msgType == MessageTypes.Text) {
          // Check for links
          final body = event.body;
          if (body.contains('http://') || body.contains('https://')) {
            links++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _photoCount = photos;
          _videoCount = videos;
          _audioCount = audios;
          _linkCount = links;
          _fileCount = files;
          _loadingMedia = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final room = widget.room;
    final isDirectChat = room.isDirectChat;
    final directUserId = room.directChatMatrixID;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        border: Border(
          bottom: BorderSide(
            color: palette.separator.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        middle: Text(
          isDirectChat ? l10n.profile : 'Room Info',
          style: TextStyle(color: palette.text),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const Gap(24),
            _buildAvatarSection(palette),
            const Gap(24),

            // User ID for direct chats
            if (isDirectChat && directUserId != null) ...[
              _buildUserIdSection(directUserId, palette),
              const Gap(16),
            ],

            _buildInfoSection(palette, l10n),
            const Gap(16),

            if (!room.encrypted) ...[
              _buildUnencryptedWarning(palette),
              const Gap(16),
            ],

            if (room.topic.isNotEmpty || !isDirectChat) ...[
              _buildSection(
                title: 'Description',
                palette: palette,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    room.topic.isEmpty ? 'No description' : room.topic,
                    style: TextStyle(
                      fontSize: 15,
                      color: room.topic.isEmpty
                          ? palette.secondaryText
                          : palette.text,
                      fontStyle: room.topic.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ),
              const Gap(16),
            ],

            if (isDirectChat && directUserId != null) ...[
              PresenceBuilder(
                userId: directUserId,
                client: widget.client,
                builder: (context, presence) {
                  if (presence == null) return const SizedBox.shrink();
                  return _buildPresenceSection(presence, palette, l10n);
                },
              ),
              const Gap(16),
            ],

            // Media section
            _buildMediaSection(palette),
            const Gap(16),

            if (!isDirectChat) ...[
              _buildMembersSection(palette, l10n),
              const Gap(16),
            ],

            _buildActionsSection(palette, l10n),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildUserIdSection(String userId, AppPalette palette) {
    return _buildSection(
      title: 'Matrix ID',
      palette: palette,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: userId));
          HapticFeedback.lightImpact();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(CupertinoIcons.at, size: 20, color: palette.secondaryText),
              const Gap(12),
              Expanded(
                child: Text(
                  userId,
                  style: TextStyle(fontSize: 14, color: palette.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                CupertinoIcons.doc_on_clipboard,
                size: 16,
                color: palette.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(AppPalette palette) {
    final room = widget.room;

    return Column(
      children: [
        GestureDetector(
          onTap: room.avatar != null
              ? () => _showAvatarFullScreen(room.avatar!)
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
              child: room.avatar != null
                  ? MxcImage(
                      uri: room.avatar!,
                      client: widget.client,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        _getInitials(room.getLocalizedDisplayname()),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w500,
                          color: palette.primary,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const Gap(16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            widget.room.getLocalizedDisplayname(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: palette.text,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _showAvatarFullScreen(Uri avatarUri) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) => AvatarViewer(
          uri: avatarUri,
          client: widget.client,
          displayName: widget.room.getLocalizedDisplayname(),
        ),
      ),
    );
  }

  Widget _buildInfoSection(AppPalette palette, AppLocalizations l10n) {
    final room = widget.room;

    return _buildSection(
      title: 'Info',
      palette: palette,
      child: Column(
        children: [
          _buildInfoTile(
            icon: CupertinoIcons.number,
            title: 'Room ID',
            value: room.id,
            palette: palette,
            onTap: () => _copyToClipboard(room.id),
          ),
          if (room.canonicalAlias.isNotEmpty) ...[
            Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),
            _buildInfoTile(
              icon: CupertinoIcons.at,
              title: 'Room Alias',
              value: room.canonicalAlias,
              palette: palette,
              onTap: () => _copyToClipboard(room.canonicalAlias),
            ),
          ],
          Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),
          _buildInfoTile(
            icon: CupertinoIcons.person_2,
            title: 'Members',
            value: '${room.summary.mJoinedMemberCount ?? 0}',
            palette: palette,
            onTap: _openMembersList,
          ),
          if (!room.isDirectChat) ...[
            Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),
            _buildInfoTile(
              icon: room.encrypted
                  ? CupertinoIcons.lock_fill
                  : CupertinoIcons.lock_open,
              title: 'Encryption',
              value: room.encrypted ? 'Enabled' : 'Disabled',
              palette: palette,
              // Make lock non-clickable as requested
              onTap: null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnencryptedWarning(AppPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
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
          const Expanded(
            child: Text(
              'This chat is not encrypted. Messages are not secure.',
              style: TextStyle(color: CupertinoColors.systemRed, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(AppPalette palette) {
    return _buildSection(
      title: 'Media, Links, Files',
      palette: palette,
      child: _loadingMedia
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : Column(
              children: [
                _buildMediaTile(
                  icon: CupertinoIcons.photo,
                  title: 'Photos',
                  count: _photoCount,
                  palette: palette,
                  onTap: () => _openMediaGallery(MessageTypes.Image),
                ),
                Divider(
                  height: 1,
                  color: palette.separator.withValues(alpha: 0.3),
                ),
                _buildMediaTile(
                  icon: CupertinoIcons.video_camera,
                  title: 'Videos',
                  count: _videoCount,
                  palette: palette,
                  onTap: () => _openMediaGallery(MessageTypes.Video),
                ),
                Divider(
                  height: 1,
                  color: palette.separator.withValues(alpha: 0.3),
                ),
                _buildMediaTile(
                  icon: CupertinoIcons.waveform,
                  title: 'Audio & Voice',
                  count: _audioCount,
                  palette: palette,
                  onTap: () => _openMediaGallery(MessageTypes.Audio),
                ),
                Divider(
                  height: 1,
                  color: palette.separator.withValues(alpha: 0.3),
                ),
                _buildMediaTile(
                  icon: CupertinoIcons.link,
                  title: 'Links',
                  count: _linkCount,
                  palette: palette,
                  onTap: _openLinksView,
                ),
                Divider(
                  height: 1,
                  color: palette.separator.withValues(alpha: 0.3),
                ),
                _buildMediaTile(
                  icon: CupertinoIcons.doc,
                  title: 'Files',
                  count: _fileCount,
                  palette: palette,
                  onTap: () => _openMediaGallery(MessageTypes.File),
                ),
              ],
            ),
    );
  }

  Widget _buildMediaTile({
    required IconData icon,
    required String title,
    required int count,
    required AppPalette palette,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: count > 0 ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.secondaryText),
            const Gap(12),
            Text(title, style: TextStyle(fontSize: 15, color: palette.text)),
            const Spacer(),
            Text(
              '$count',
              style: TextStyle(fontSize: 15, color: palette.secondaryText),
            ),
            const Gap(4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: palette.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  void _openMediaGallery(String mediaType) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => MediaGalleryScreen(
          room: widget.room,
          client: widget.client,
          mediaType: mediaType,
        ),
      ),
    );
  }

  void _openLinksView() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => LinksScreen(room: widget.room, client: widget.client),
      ),
    );
  }

  void _openMembersList() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            RoomMembersScreen(room: widget.room, client: widget.client),
      ),
    );
  }

  Widget _buildPresenceSection(
    CachedPresence presence,
    AppPalette palette,
    AppLocalizations l10n,
  ) {
    String statusText;
    Color statusColor;

    if (presence.currentlyActive == true) {
      statusText = l10n.online;
      statusColor = CupertinoColors.activeGreen;
    } else if (presence.lastActiveTimestamp != null) {
      final lastSeen = presence.lastActiveTimestamp!;
      final diff = DateTime.now().difference(lastSeen);

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
        statusText = l10n.lastSeenAt(AppDateFormats.monthDay.format(lastSeen));
        statusColor = CupertinoColors.systemGrey;
      }
    } else {
      statusText = l10n.offline;
      statusColor = CupertinoColors.systemGrey;
    }

    return _buildSection(
      title: 'Status',
      palette: palette,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const Gap(10),
            Text(
              statusText,
              style: TextStyle(fontSize: 15, color: palette.text),
            ),
            if (presence.statusMsg != null &&
                presence.statusMsg!.isNotEmpty) ...[
              const Gap(16),
              Expanded(
                child: Text(
                  presence.statusMsg!,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: palette.secondaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(AppPalette palette, AppLocalizations l10n) {
    return _buildSection(
      title: 'Members',
      palette: palette,
      child: _loadingMembers
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : Column(
              children: [
                for (var i = 0; i < (_members?.take(10).length ?? 0); i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: palette.separator.withValues(alpha: 0.3),
                    ),
                  _buildMemberTile(_members![i], palette),
                ],
                if ((_members?.length ?? 0) > 10) ...[
                  Divider(
                    height: 1,
                    color: palette.separator.withValues(alpha: 0.3),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: _openMembersList,
                    child: Text(
                      'View all ${_members!.length} members',
                      style: TextStyle(fontSize: 15, color: palette.primary),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildMemberTile(User member, palette) {
    final isAdmin = member.powerLevel >= 100;
    final isModerator = member.powerLevel >= 50 && member.powerLevel < 100;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        UserProfileDialog.show(
          context: context,
          profile: Profile(
            userId: member.id,
            displayName: member.displayName,
            avatarUrl: member.avatarUrl,
          ),
          client: widget.client,
          room: widget.room,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            MatrixAvatar(
              avatarUrl: member.avatarUrl,
              name: member.calcDisplayname(),
              client: widget.client,
              size: 40,
              userId: member.id,
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.calcDisplayname(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                    ),
                  ),
                  if (isAdmin || isModerator)
                    Text(
                      isAdmin ? 'Admin' : 'Moderator',
                      style: TextStyle(
                        fontSize: 12,
                        color: isAdmin
                            ? CupertinoColors.systemRed
                            : CupertinoColors.systemOrange,
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

  Widget _buildActionsSection(AppPalette palette, AppLocalizations l10n) {
    final room = widget.room;

    // Get current notification state
    final pushState = room.pushRuleState;
    String notificationStatus;
    if (pushState == PushRuleState.dontNotify) {
      notificationStatus = l10n.notificationsMuted;
    } else if (pushState == PushRuleState.mentionsOnly) {
      notificationStatus = l10n.mentionsOnly;
    } else {
      notificationStatus = l10n.notificationsOn;
    }

    return _buildSection(
      title: 'Actions',
      palette: palette,
      child: Column(
        children: [
          if (room.isDirectChat &&
              room.encrypted &&
              room.directChatMatrixID != null) ...[
            _buildActionTile(
              icon: CupertinoIcons.lock_shield_fill,
              title: 'Verify User',
              palette: palette,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => UserVerificationScreen(
                    client: widget.client,
                    userId: room.directChatMatrixID!,
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),
          ],
          _buildActionTile(
            icon: CupertinoIcons.search,
            title: 'Search in Chat',
            palette: palette,
            onTap: _openSearch,
          ),
          Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),

          if (room.canChangeStateEvent(EventTypes.RoomJoinRules)) ...[
            _buildActionTile(
              icon: CupertinoIcons.eye,
              title: 'Access & Visibility',
              palette: palette,
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => AccessAndVisibilityScreen(room: room),
                ),
              ),
            ),
            Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),
          ],

          if (room.canChangePowerLevel) ...[
            _buildActionTile(
              icon: CupertinoIcons.shield_fill,
              title: 'Chat Permissions',
              palette: palette,
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => ChatPermissionsScreen(room: room),
                ),
              ),
            ),
            Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),
          ],

          _buildActionTile(
            icon: pushState == PushRuleState.dontNotify
                ? CupertinoIcons.bell_slash
                : CupertinoIcons.bell,
            title: l10n.notifications,
            subtitle: notificationStatus,
            palette: palette,
            onTap: () => _showNotificationSettings(l10n, palette),
          ),
          Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),
          _buildActionTile(
            icon: room.isDirectChat
                ? CupertinoIcons.delete
                : CupertinoIcons.arrow_right_square,
            title: room.isDirectChat ? 'Delete Chat' : 'Leave Group',
            palette: palette,
            isDestructive: true,
            onTap: () => _showLeaveConfirmation(room.isDirectChat),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotificationSettings(AppLocalizations l10n, palette) async {
    final room = widget.room;
    final currentState = room.pushRuleState;

    final result = await showCupertinoModalPopup<PushRuleState>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(l10n.notificationsSettings),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, PushRuleState.notify),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentState == PushRuleState.notify)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark, size: 18),
                  ),
                Text(l10n.allMessages),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, PushRuleState.mentionsOnly),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentState == PushRuleState.mentionsOnly)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark, size: 18),
                  ),
                Text(l10n.mentionsOnly),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, PushRuleState.dontNotify),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentState == PushRuleState.dontNotify)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark, size: 18),
                  ),
                Text(l10n.muteNotifications),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );

    if (result != null && result != currentState) {
      try {
        await room.setPushRuleState(result);
        if (mounted) {
          setState(() {}); // Refresh UI
          // Show success feedback
          HapticFeedback.lightImpact();
        }
      } catch (e) {
        if (mounted) {
          showCupertinoDialog<void>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text(l10n.error),
              content: Text(l10n.roomNotificationError),
              actions: [
                CupertinoDialogAction(
                  child: Text(l10n.ok),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            ChatSearchScreen(room: widget.room, client: widget.client),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required palette,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: palette.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: palette.inputBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required AppPalette palette,
    VoidCallback? onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.secondaryText),
            const Gap(12),
            SizedBox(
              width: 110,
              child: Text(
                title,
                style: TextStyle(fontSize: 15, color: palette.text),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(fontSize: 15, color: palette.secondaryText),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
            ),
            if (onTap != null) ...[
              const Gap(8),
              Icon(
                title == 'Members'
                    ? CupertinoIcons.chevron_right
                    : CupertinoIcons.doc_on_clipboard,
                size: title == 'Members' ? 16 : 16,
                color: title == 'Members'
                    ? palette.secondaryText
                    : palette.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required palette,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final color = isDestructive ? CupertinoColors.systemRed : palette.text;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const Gap(12),
            Text(title, style: TextStyle(fontSize: 16, color: color)),
            const Spacer(),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(fontSize: 15, color: palette.secondaryText),
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
  }

  Future<void> _showLeaveConfirmation(bool isDirectChat) async {
    final l10n = AppLocalizations.of(context)!;
    // final canDelete = !isDirectChat; // Simplified check or remove if not needed for logic below yet

    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(isDirectChat ? 'Delete Chat?' : 'Leave Group?'),
        message: Text(
          isDirectChat
              ? 'This will delete the chat history for you.'
              : 'Are you sure you want to leave this group?',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'leave'),
            child: Text(isDirectChat ? 'Delete' : 'Leave'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );

    if (result != null && context.mounted) {
      try {
        if (result == 'leave') {
          await widget.room.leave();
        } else if (result == 'forget') {
          await widget.room.leave();
          await widget.room.forget();
        }

        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (!mounted) return;
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

// =============================================================================
// CHAT SEARCH SCREEN
// =============================================================================

class ChatSearchScreen extends StatefulWidget {
  final Room room;
  final Client client;

  const ChatSearchScreen({super.key, required this.room, required this.client});

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _searchController = TextEditingController();
  List<Event> _results = [];
  bool _loading = false;
  Timeline? _timeline;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    _timeline = await widget.room.getTimeline();
    // Load more history for search
    var attempts = 0;
    while (_timeline!.canRequestHistory && attempts < 3) {
      await _timeline!.requestHistory(historyCount: 100);
      attempts++;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty || _timeline == null) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);

    // Load more history while searching
    if (_timeline!.canRequestHistory) {
      await _timeline!.requestHistory(historyCount: 100);
    }

    final lowerQuery = query.toLowerCase();
    final matches = _timeline!.events.where((event) {
      if (event.type != EventTypes.Message) return false;
      if (event.messageType != MessageTypes.Text) return false;
      return event.body.toLowerCase().contains(lowerQuery);
    }).toList();

    if (mounted) {
      setState(() {
        _results = matches;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        middle: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: 'Search messages...',
          autofocus: true,
          onChanged: _search,
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _results.isEmpty
            ? Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? 'Enter text to search'
                      : 'No results found',
                  style: TextStyle(color: palette.secondaryText),
                ),
              )
            : ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: palette.separator.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final event = _results[index];
                  final sender = event.senderFromMemoryOrFallback;

                  return CupertinoListTile(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: MatrixAvatar(
                      avatarUrl: sender.avatarUrl,
                      name: sender.calcDisplayname(),
                      client: widget.client,
                      size: 40,
                      userId: sender.id,
                    ),
                    title: Text(
                      sender.calcDisplayname(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    subtitle: Text(
                      event.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.secondaryText),
                    ),
                    trailing: Text(
                      AppDateFormats.monthDay.format(event.originServerTs),
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.secondaryText,
                      ),
                    ),
                    onTap: () {
                      // TODO: Navigate to message in chat
                      Navigator.pop(context);
                    },
                  );
                },
              ),
      ),
    );
  }
}

// =============================================================================
// MEDIA GALLERY SCREEN
// =============================================================================

class MediaGalleryScreen extends StatefulWidget {
  final Room room;
  final Client client;
  final String mediaType;

  const MediaGalleryScreen({
    super.key,
    required this.room,
    required this.client,
    required this.mediaType,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  List<Event> _mediaEvents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final timeline = await widget.room.getTimeline();

      // Request more history to find media
      var attempts = 0;
      while (timeline.canRequestHistory && attempts < 5) {
        await timeline.requestHistory(historyCount: 100);
        attempts++;
        // Check if we found enough media
        final foundMedia = timeline.events.where((e) {
          if (e.type != EventTypes.Message) return false;
          return e.messageType == widget.mediaType;
        }).length;
        if (foundMedia >= 50) break;
      }

      final events = timeline.events.where((e) {
        if (e.type != EventTypes.Message) return false;
        return e.messageType == widget.mediaType;
      }).toList();

      if (mounted) {
        setState(() {
          _mediaEvents = events;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _title {
    switch (widget.mediaType) {
      case MessageTypes.Image:
        return 'Photos';
      case MessageTypes.Video:
        return 'Videos';
      case MessageTypes.Audio:
        return 'Audio';
      case MessageTypes.File:
        return 'Files';
      default:
        return 'Media';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        middle: Text(_title, style: TextStyle(color: palette.text)),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _mediaEvents.isEmpty
            ? Center(
                child: Text(
                  'No $_title found',
                  style: TextStyle(color: palette.secondaryText),
                ),
              )
            : widget.mediaType == MessageTypes.Image
            ? _buildImageGrid()
            : _buildMediaList(),
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _mediaEvents.length,
      itemBuilder: (context, index) {
        final event = _mediaEvents[index];
        final mxcUri = event.content.tryGet<String>('url');

        if (mxcUri == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            // TODO: Open full screen viewer
          },
          child: MxcImage(
            uri: Uri.parse(mxcUri),
            client: widget.client,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Widget _buildMediaList() {
    final palette = context.watch<ThemeController>().palette;

    return ListView.separated(
      itemCount: _mediaEvents.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: palette.separator.withValues(alpha: 0.3)),
      itemBuilder: (context, index) {
        final event = _mediaEvents[index];
        final sender = event.senderFromMemoryOrFallback;
        final filename = event.content.tryGet<String>('body') ?? 'File';

        return CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Icon(
            widget.mediaType == MessageTypes.Audio
                ? CupertinoIcons.waveform
                : CupertinoIcons.doc,
            color: palette.primary,
          ),
          title: Text(
            filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.text),
          ),
          subtitle: Text(
            '${sender.calcDisplayname()} • ${AppDateFormats.monthDay.format(event.originServerTs)}',
            style: TextStyle(fontSize: 12, color: palette.secondaryText),
          ),
          onTap: () {
            // TODO: Open file/audio player
          },
        );
      },
    );
  }
}

// =============================================================================
// LINKS SCREEN
// =============================================================================

class LinksScreen extends StatefulWidget {
  final Room room;
  final Client client;

  const LinksScreen({super.key, required this.room, required this.client});

  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  List<(Event, String)> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    try {
      final timeline = await widget.room.getTimeline();

      // Request more history to find links
      var attempts = 0;
      while (timeline.canRequestHistory && attempts < 5) {
        await timeline.requestHistory(historyCount: 100);
        attempts++;
      }

      final linkRegex = RegExp(r'https?://[^\s]+');

      final links = <(Event, String)>[];
      for (final event in timeline.events) {
        if (event.type != EventTypes.Message) continue;
        if (event.messageType != MessageTypes.Text) continue;

        final matches = linkRegex.allMatches(event.body);
        for (final match in matches) {
          links.add((event, match.group(0)!));
        }
      }

      if (mounted) {
        setState(() {
          _links = links;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        middle: Text('Links', style: TextStyle(color: palette.text)),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _links.isEmpty
            ? Center(
                child: Text(
                  'No links found',
                  style: TextStyle(color: palette.secondaryText),
                ),
              )
            : ListView.separated(
                itemCount: _links.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: palette.separator.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final (event, link) = _links[index];
                  final sender = event.senderFromMemoryOrFallback;

                  return CupertinoListTile(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: Icon(CupertinoIcons.link, color: palette.primary),
                    title: Text(
                      link,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    subtitle: Text(
                      '${sender.calcDisplayname()} • ${AppDateFormats.monthDay.format(event.originServerTs)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.secondaryText,
                      ),
                    ),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: link));
                      HapticFeedback.lightImpact();
                    },
                  );
                },
              ),
      ),
    );
  }
}
