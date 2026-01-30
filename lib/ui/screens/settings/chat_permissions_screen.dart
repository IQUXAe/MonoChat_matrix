import 'package:flutter/cupertino.dart';

import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

class ChatPermissionsScreen extends StatefulWidget {
  final Room room;

  const ChatPermissionsScreen({super.key, required this.room});

  @override
  State<ChatPermissionsScreen> createState() => _ChatPermissionsScreenState();
}

class _ChatPermissionsScreenState extends State<ChatPermissionsScreen> {
  // Common permission keys
  static const _keys = [
    'invite',
    'kick',
    'ban',
    'redact',
    'events_default',
    'state_default',
    'users_default',
  ];

  static const _eventKeys = {
    'm.room.name': 'Change Room Name',
    'm.room.topic': 'Change Topic',
    'm.room.avatar': 'Change Avatar',
    'm.room.power_levels': 'Change Permissions',
    'm.room.history_visibility': 'Change History Visibility',
    'm.room.canonical_alias': 'Change Addresses',
    'm.room.tombstone': 'Upgrade Room',
  };

  bool _isLoading = false;

  void _setLoading(bool loading) {
    if (mounted) setState(() => _isLoading = loading);
  }

  Future<void> _updatePowerLevel(
    String key,
    int level, {
    String? category,
  }) async {
    _setLoading(true);
    try {
      final currentContent = Map<String, dynamic>.from(
        widget.room.getState(EventTypes.RoomPowerLevels)?.content ?? {},
      );

      if (category == 'events') {
        final events = Map<String, dynamic>.from(
          currentContent['events'] ?? {},
        );
        events[key] = level;
        currentContent['events'] = events;
      } else {
        currentContent[key] = level;
      }

      await widget.room.client.setRoomStateWithKey(
        widget.room.id,
        EventTypes.RoomPowerLevels,
        '',
        currentContent,
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  void _showError(Object e) {
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

  Map<String, int> _getAvailableLevels() {
    // Typically: User (0), Moderator (50), Admin (100)
    return {'User': 0, 'Moderator': 50, 'Admin': 100};
  }

  void _showLevelPicker(
    String title,
    int currentLevel,
    Function(int) onSelected,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Select Level for $title'),
        actions: [
          for (final entry in _getAvailableLevels().entries)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onSelected(entry.value);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.key),
                  if (entry.value == currentLevel)
                    const Text(' (Current)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          // Custom level option could go here
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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
        middle: Text('Chat Permissions', style: TextStyle(color: palette.text)),
      ),
      child: SafeArea(
        child: StreamBuilder(
          stream: room.client.onRoomState.stream.where(
            (e) =>
                e.roomId == room.id &&
                e.state.type == EventTypes.RoomPowerLevels,
          ),
          builder: (context, snapshot) {
            final content =
                room.getState(EventTypes.RoomPowerLevels)?.content ?? {};
            final events = content.tryGetMap<String, dynamic>('events') ?? {};

            return ListView(
              children: [
                if (_isLoading)
                  const SizedBox(
                    height: 2,
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                const Gap(16),

                _buildSectionHeader('GENERAL', palette),
                for (final key in _keys)
                  _buildPermissionTile(
                    title: _formatName(key),
                    level:
                        content.tryGet<int>(key) ??
                        (key.contains('default') ? 0 : 50), // Defaults roughly
                    palette: palette,
                    onChanged: (v) => _updatePowerLevel(key, v),
                  ),

                const Gap(24),
                _buildSectionHeader('SPECIFIC ACTIONS', palette),
                for (final entry in _eventKeys.entries)
                  _buildPermissionTile(
                    title: entry.value,
                    level:
                        events.tryGet<int>(entry.key) ??
                        (content.tryGet<int>('events_default') ?? 0),
                    palette: palette,
                    onChanged: (v) =>
                        _updatePowerLevel(entry.key, v, category: 'events'),
                  ),

                const Gap(40),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatName(String key) {
    return key.replaceAll('_', ' ').toUpperCase();
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

  Widget _buildPermissionTile({
    required String title,
    required int level,
    required dynamic palette,
    required Function(int) onChanged,
  }) {
    String levelName = 'User ($level)';
    if (level >= 100)
      levelName = 'Admin ($level)';
    else if (level >= 50)
      levelName = 'Moderator ($level)';
    else if (level == 0)
      levelName = 'User (0)';
    else
      levelName = 'Level $level';

    return Container(
      color: palette.inputBackground,
      margin: const EdgeInsets.only(bottom: 1),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onPressed: () {
          if (!widget.room.canChangePowerLevel) {
            _showError('You do not have permission to change this.');
            return;
          }
          _showLevelPicker(title, level, onChanged);
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: palette.text, fontSize: 16),
              ),
            ),
            Text(
              levelName,
              style: TextStyle(color: palette.secondaryText, fontSize: 14),
            ),
            const Gap(4),
            Icon(
              CupertinoIcons.chevron_up_chevron_down,
              size: 14,
              color: palette.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
