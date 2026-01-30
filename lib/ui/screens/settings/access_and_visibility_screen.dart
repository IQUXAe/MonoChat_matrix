import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart' hide Visibility;
import 'package:matrix/matrix.dart' as matrix_sdk show Visibility;
import 'package:monochat/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

class AccessAndVisibilityScreen extends StatefulWidget {
  final Room room;

  const AccessAndVisibilityScreen({super.key, required this.room});

  @override
  State<AccessAndVisibilityScreen> createState() =>
      _AccessAndVisibilityScreenState();
}

class _AccessAndVisibilityScreenState extends State<AccessAndVisibilityScreen> {
  bool _isLoading = false;

  void _setLoading(bool loading) {
    if (mounted) setState(() => _isLoading = loading);
  }

  Future<void> _updateJoinRule(JoinRules rule) async {
    _setLoading(true);
    try {
      await widget.room.setJoinRules(rule);
    } catch (e) {
      _showError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _updateHistoryVisibility(HistoryVisibility visibility) async {
    _setLoading(true);
    try {
      await widget.room.setHistoryVisibility(visibility);
    } catch (e) {
      _showError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _updateGuestAccess(GuestAccess access) async {
    _setLoading(true);
    try {
      await widget.room.setGuestAccess(access);
    } catch (e) {
      _showError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _toggleDirectoryVisibility(bool visible) async {
    _setLoading(true);
    try {
      await widget.room.client.setRoomVisibilityOnDirectory(
        widget.room.id,
        visibility: visible
            ? matrix_sdk.Visibility.public
            : matrix_sdk.Visibility.private,
      );
      setState(() {});
    } catch (e) {
      _showError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _addAlias() async {
    final domain = widget.room.client.userID?.domain;
    if (domain == null) return;

    final controller = TextEditingController();
    final alias = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add Alias'),
        content: Column(
          children: [
            const Text('Enter local part of the alias:'),
            const Gap(8),
            CupertinoTextField(
              controller: controller,
              placeholder: 'alias',
              suffix: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  ':$domain',
                  style: const TextStyle(color: CupertinoColors.systemGrey),
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (alias == null || alias.isEmpty) return;

    final fullAlias = '#$alias:$domain';
    _setLoading(true);
    try {
      await widget.room.client.setRoomAlias(fullAlias, widget.room.id);

      // Ask to canonical
      if (mounted &&
          widget.room.canChangeStateEvent(EventTypes.RoomCanonicalAlias)) {
        final makeCanonical = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Set as Canonical?'),
            content: Text(
              'Do you want to make $fullAlias the main address for this room?',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );

        if (makeCanonical == true) {
          // Handle canonical logic carefully (preserving alt_aliases)
          final currentContent = widget.room
              .getState(EventTypes.RoomCanonicalAlias)
              ?.content;
          final altAliases = Set<String>.from(
            currentContent?.tryGetList<String>('alt_aliases') ?? [],
          );

          // Add old canonical to alt if it exists
          if (widget.room.canonicalAlias.isNotEmpty) {
            altAliases.add(widget.room.canonicalAlias);
          }
          // Ensure new alias is not in alt
          altAliases.remove(fullAlias);

          await widget.room.client.setRoomStateWithKey(
            widget.room.id,
            EventTypes.RoomCanonicalAlias,
            '',
            {'alias': fullAlias, 'alt_aliases': altAliases.toList()},
          );
        }
      }
      setState(() {});
    } catch (e) {
      _showError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _upgradeRoom() async {
    _setLoading(true);
    try {
      final caps = await widget.room.client.getCapabilities();
      // Use latest available version as default if defaultVersion is missing
      final defaultVer = caps.mRoomVersions?.available.keys.last ?? '10';

      if (!mounted) return;

      final confirm = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Upgrade Room'),
          content: Text(
            'This will archive the current room and create a new version ($defaultVer). Messages will be preserved in the archive. Proceed?',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Upgrade'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        _setLoading(false);
        return;
      }

      await widget.room.client.upgradeRoom(widget.room.id, defaultVer);

      if (mounted) {
        Navigator.pop(context); // Close settings
      }
    } catch (e) {
      _showError(e);
    } finally {
      _setLoading(false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(e.toString()),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final room = widget.room;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        middle: Text(
          'Access & Visibility',
          style: TextStyle(color: palette.text),
        ),
      ),
      child: SafeArea(
        child: StreamBuilder(
          stream: room.client.onRoomState.stream.where(
            (e) => e.roomId == room.id,
          ),
          builder: (context, snapshot) {
            return ListView(
              children: [
                if (_isLoading)
                  const SizedBox(
                    height: 2,
                    child: Center(child: CupertinoActivityIndicator()),
                  ),

                _buildSectionHeader('WHO CAN JOIN', palette),
                _buildSelectionTile<JoinRules>(
                  title: 'Public',
                  value: JoinRules.public,
                  groupValue: room.joinRules,
                  palette: palette,
                  onChanged: _updateJoinRule,
                ),
                _buildDivider(palette),
                _buildSelectionTile<JoinRules>(
                  title: 'Knock (Request to join)',
                  value: JoinRules.knock,
                  groupValue: room.joinRules,
                  palette: palette,
                  onChanged: _updateJoinRule,
                ),
                _buildDivider(palette),
                _buildSelectionTile<JoinRules>(
                  title: 'Invite Only',
                  value: JoinRules.invite,
                  groupValue: room.joinRules,
                  palette: palette,
                  onChanged: _updateJoinRule,
                ),

                const Gap(24),
                _buildSectionHeader('HISTORY VISIBILITY', palette),
                _buildSelectionTile<HistoryVisibility>(
                  title: 'Shared (Visible since join)',
                  value: HistoryVisibility.shared,
                  groupValue: room.historyVisibility,
                  palette: palette,
                  onChanged: _updateHistoryVisibility,
                ),
                _buildDivider(palette),
                _buildSelectionTile<HistoryVisibility>(
                  title: 'Invited (Visible since invite)',
                  value: HistoryVisibility.invited,
                  groupValue: room.historyVisibility,
                  palette: palette,
                  onChanged: _updateHistoryVisibility,
                ),
                _buildDivider(palette),
                _buildSelectionTile<HistoryVisibility>(
                  title: 'Joined (Visible since joined)',
                  value: HistoryVisibility.joined,
                  groupValue: room.historyVisibility,
                  palette: palette,
                  onChanged: _updateHistoryVisibility,
                ),
                _buildDivider(palette),
                _buildSelectionTile<HistoryVisibility>(
                  title: 'World Readable',
                  value: HistoryVisibility.worldReadable,
                  groupValue: room.historyVisibility,
                  palette: palette,
                  onChanged: _updateHistoryVisibility,
                ),

                if (room.joinRules == JoinRules.public) ...[
                  const Gap(24),
                  _buildSectionHeader('GUEST ACCESS', palette),
                  _buildSelectionTile<GuestAccess>(
                    title: 'Can Join',
                    value: GuestAccess.canJoin,
                    groupValue: room.guestAccess,
                    palette: palette,
                    onChanged: _updateGuestAccess,
                  ),
                  _buildDivider(palette),
                  _buildSelectionTile<GuestAccess>(
                    title: 'Forbidden',
                    value: GuestAccess.forbidden,
                    groupValue: room.guestAccess,
                    palette: palette,
                    onChanged: _updateGuestAccess,
                  ),
                ],

                const Gap(24),
                _buildSectionHeader('ROOM ADDRESSES (ALIASES)', palette),
                // Canonical Alias
                if (room.canonicalAlias.isNotEmpty)
                  _buildAliasTile(room.canonicalAlias, true, palette),

                // Alt Aliases
                ...?room
                    .getState(EventTypes.RoomCanonicalAlias)
                    ?.content
                    .tryGetList<String>('alt_aliases')
                    ?.map((a) => _buildAliasTile(a, false, palette)),

                CupertinoButton(
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.add),
                      Gap(8),
                      Text('Add new address'),
                    ],
                  ),
                  onPressed: _addAlias,
                ),

                const Gap(24),
                _buildSectionHeader('DIRECTORY', palette),
                FutureBuilder<matrix_sdk.Visibility?>(
                  future: room.client.getRoomVisibilityOnDirectory(room.id),
                  builder: (context, snapshot) {
                    final isPublic =
                        snapshot.data == matrix_sdk.Visibility.public;
                    return Container(
                      color: palette.inputBackground,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Publish to directory',
                              style: TextStyle(color: palette.text),
                            ),
                          ),
                          CupertinoSwitch(
                            value: isPublic,
                            onChanged: (v) => _toggleDirectoryVisibility(v),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const Gap(24),
                _buildSectionHeader('ROOM VERSION', palette),
                Container(
                  color: palette.inputBackground,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Version: ${room.roomVersion}',
                        style: TextStyle(color: palette.text),
                      ),
                      const Spacer(),
                      if (room.canSendEvent(EventTypes.RoomTombstone))
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Text('Upgrade'),
                          onPressed: _upgradeRoom,
                        ),
                    ],
                  ),
                ),
                const Gap(40),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, dynamic palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: palette.secondaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSelectionTile<T>({
    required String title,
    required T value,
    required T? groupValue,
    required dynamic palette,
    required Function(T) onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        color: palette.inputBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(color: palette.text)),
            ),
            if (isSelected)
              Icon(CupertinoIcons.checkmark_alt, color: palette.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildAliasTile(String alias, bool isCanonical, dynamic palette) {
    return Container(
      color: palette.inputBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Icon(
            isCanonical ? CupertinoIcons.star_fill : CupertinoIcons.link,
            size: 16,
            color: palette.secondaryText,
          ),
          const Gap(12),
          Expanded(
            child: Text(alias, style: TextStyle(color: palette.text)),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(
              CupertinoIcons.trash,
              size: 20,
              color: CupertinoColors.systemRed,
            ),
            onPressed: () => _deleteAlias(alias),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAlias(String alias) async {
    _setLoading(true);
    try {
      await widget.room.client.deleteRoomAlias(alias);
      setState(() {});
    } catch (e) {
      _showError(e);
    } finally {
      _setLoading(false);
    }
  }

  Widget _buildDivider(dynamic palette) {
    return Container(
      color: palette.inputBackground,
      child: Divider(
        height: 1,
        indent: 16,
        color: palette.separator.withValues(alpha: 0.2),
      ),
    );
  }
}
