import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/space_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/screens/chat_screen.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';

// =============================================================================
// SPACE VIEW SCREEN
// =============================================================================

class SpaceViewScreen extends StatefulWidget {
  final String spaceId;
  final VoidCallback onBack;

  const SpaceViewScreen({
    super.key,
    required this.spaceId,
    required this.onBack,
  });

  @override
  State<SpaceViewScreen> createState() => _SpaceViewScreenState();
}

class _SpaceViewScreenState extends State<SpaceViewScreen> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<SyncUpdate>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadSpace();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSpace() async {
    final spaceController = context.read<SpaceController>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await spaceController.setActiveSpace(widget.spaceId);
    });
  }

  void _onSearchChanged(String value) {
    context.read<SpaceController>().setFilter(value);
  }

  Future<void> _onChildTap(SpaceRoomsChunk$2 child) async {
    final spaceController = context.read<SpaceController>();
    final client = context.read<AuthController>().client!;

    // Check if already joined
    var room = client.getRoomById(child.roomId);

    if (room == null || room.membership == Membership.leave) {
      // Show join dialog
      final shouldJoin = await _showJoinDialog(child);
      if (!shouldJoin) return;

      room = await spaceController.joinSpaceChild(child);
      if (room == null) {
        if (mounted) {
          _showErrorDialog(AppLocalizations.of(context)!.error);
        }
        return;
      }
    }

    if (room.isSpace) {
      // Navigate into subspace
      await spaceController.setActiveSpace(room.id);
    } else {
      // Open chat
      if (mounted) {
        Navigator.of(
          context,
        ).push(CupertinoPageRoute(builder: (_) => ChatScreen(room: room!)));
      }
    }
  }

  Future<bool> _showJoinDialog(SpaceRoomsChunk$2 child) async {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.read<ThemeController>().palette;

    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(l10n.joinRoom),
            content: Column(
              children: [
                const Gap(12),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.inputBackground,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: MatrixAvatar(
                    avatarUrl: child.avatarUrl,
                    name: child.name ?? child.roomId,
                    client: context.read<AuthController>().client!,
                    size: 60,
                  ),
                ),
                const Gap(12),
                Text(
                  child.name ?? child.canonicalAlias ?? child.roomId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (child.topic != null && child.topic!.isNotEmpty) ...[
                  const Gap(8),
                  Text(
                    child.topic!,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.secondaryText,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Gap(8),
                Text(
                  '${child.numJoinedMembers} members',
                  style: TextStyle(fontSize: 13, color: palette.secondaryText),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.joinRoom),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.error),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  void _showAddOptions() {
    final l10n = AppLocalizations.of(context)!;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(l10n.addToSpace),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showCreateGroupDialog();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.group_solid, size: 20),
                const Gap(8),
                Text(l10n.createGroup),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showCreateSubspaceDialog();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.folder_solid, size: 20),
                const Gap(8),
                Text(l10n.createSubspace),
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
  }

  Future<void> _showCreateGroupDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();

    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.createGroup),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: l10n.groupName,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (name == null || name.isEmpty) return;

    if (!mounted) return;
    final spaceController = context.read<SpaceController>();
    final roomId = await spaceController.createGroupInSpace(name: name);

    if (roomId != null && mounted) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _showCreateSubspaceDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();

    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.createSubspace),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: l10n.spaceName,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (name == null || name.isEmpty) return;

    if (!mounted) return;
    final spaceController = context.read<SpaceController>();
    final roomId = await spaceController.createSubspace(name: name);

    if (roomId != null && mounted) {
      HapticFeedback.mediumImpact();
    }
  }

  void _showSpaceOptions() {
    final l10n = AppLocalizations.of(context)!;
    final spaceController = context.read<SpaceController>();
    final space = spaceController.activeSpace;
    if (space == null) return;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openSpaceSettings();
            },
            child: Text(l10n.settings),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _inviteToSpace();
            },
            child: Text(l10n.invite),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showMembers();
            },
            child: Text(
              '${space.summary.mJoinedMemberCount ?? 0} ${l10n.members}',
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _leaveSpace();
            },
            child: Text(l10n.leave),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  void _openSpaceSettings() {
    // TODO: Navigate to space settings
  }

  void _inviteToSpace() {
    // TODO: Navigate to invite screen
  }

  void _showMembers() {
    // TODO: Navigate to members list
  }

  Future<void> _leaveSpace() async {
    final l10n = AppLocalizations.of(context)!;
    final spaceController = context.read<SpaceController>();
    final space = spaceController.activeSpace;
    if (space == null) return;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.leave),
        content: Text(l10n.leaveSpaceConfirmation),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await space.leave();
    spaceController.clearActiveSpace();
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final client = context.watch<AuthController>().client!;
    final spaceController = context.watch<SpaceController>();
    final space = client.getRoomById(widget.spaceId);
    final l10n = AppLocalizations.of(context)!;

    if (space == null) {
      return CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.folder_badge_minus,
                size: 64,
                color: CupertinoColors.systemGrey,
              ),
              const Gap(16),
              Text(
                l10n.spaceNotFound,
                style: TextStyle(color: palette.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    final displayName = space.getLocalizedDisplayname();
    final children = spaceController.filteredChildren;
    final canManage = spaceController.canManageSpaceChildren;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        border: Border(
          bottom: BorderSide(
            color: palette.separator.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            // Clear active space state
            widget.onBack();
            // Actually navigate back
            Navigator.of(context).pop();
          },
          child: const Icon(CupertinoIcons.arrow_left),
        ),
        middle: Text(
          displayName,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canManage)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showAddOptions,
                child: const Icon(CupertinoIcons.add),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showSpaceOptions,
              child: const Icon(CupertinoIcons.ellipsis_circle),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: palette.inputBackground,
                      border: Border.all(
                        color: palette.separator.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: MatrixAvatar(
                      avatarUrl: space.avatar,
                      name: displayName,
                      client: client,
                      size: 64,
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: palette.text,
                          ),
                        ),
                        if (space.topic.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              space.topic,
                              style: TextStyle(
                                fontSize: 14,
                                color: palette.secondaryText,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: l10n.search,
                onChanged: _onSearchChanged,
                style: TextStyle(color: palette.text),
                backgroundColor: palette.inputBackground,
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(
                children,
                spaceController,
                client,
                palette,
                l10n,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    List<SpaceRoomsChunk$2> children,
    SpaceController spaceController,
    Client client,
    palette,
    AppLocalizations l10n,
  ) {
    if (spaceController.isLoading && children.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (children.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.inputBackground,
              ),
              child: Icon(
                CupertinoIcons.folder_open,
                size: 48,
                color: palette.secondaryText,
              ),
            ),
            const Gap(16),
            Text(
              l10n.emptySpace,
              style: TextStyle(color: palette.secondaryText, fontSize: 16),
            ),
            if (spaceController.canManageSpaceChildren) ...[
              const Gap(24),
              CupertinoButton.filled(
                onPressed: _showAddOptions,
                child: Text(l10n.addToSpace),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 76,
        endIndent: 0,
        color: palette.separator.withValues(alpha: 0.2),
      ),
      itemCount: children.length + (spaceController.canLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == children.length) {
          // Load more button
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: spaceController.isLoading
                  ? const CupertinoActivityIndicator()
                  : CupertinoButton(
                      onPressed: spaceController.loadMore,
                      child: Text(l10n.loadMore),
                    ),
            ),
          );
        }

        final child = children[index];
        return _SpaceChildTile(
          child: child,
          client: client,
          palette: palette,
          onTap: () => _onChildTap(child),
        );
      },
    );
  }
}

// =============================================================================
// SPACE CHILD TILE
// =============================================================================

class _SpaceChildTile extends StatelessWidget {
  final SpaceRoomsChunk$2 child;
  final Client client;
  final dynamic palette;
  final VoidCallback onTap;

  const _SpaceChildTile({
    required this.child,
    required this.client,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSpace = child.roomType == 'm.space';
    final joinedRoom = client.getRoomById(child.roomId);
    final isJoined =
        joinedRoom != null && joinedRoom.membership != Membership.leave;

    // Prefer name, then canonical alias, then room ID
    var displayName = child.name ?? child.canonicalAlias ?? child.roomId;
    if (displayName.isEmpty) displayName = child.roomId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.inputBackground,
                  borderRadius: BorderRadius.circular(isSpace ? 12 : 24),
                  border: Border.all(
                    color: palette.separator.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: MatrixAvatar(
                  avatarUrl: child.avatarUrl,
                  name: displayName,
                  client: client,
                  size: 48,
                ),
              ),
              const Gap(12),

              // Info
              Expanded(
                child: Opacity(
                  opacity: isJoined ? 1.0 : 0.8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      if (child.topic != null && child.topic!.isNotEmpty)
                        Text(
                          child.topic!,
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          '${child.numJoinedMembers} members',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Trailing
              if (isJoined && joinedRoom.notificationCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${joinedRoom.notificationCount}',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (!isJoined)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.inputBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Join',
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
