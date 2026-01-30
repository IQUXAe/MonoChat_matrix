import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

class SystemMessageItem extends StatelessWidget {
  final Event event;

  const SystemMessageItem({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final text = _getSystemMessageText(event);

    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String? _getSystemMessageText(Event event) {
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();

    switch (event.type) {
      case EventTypes.RoomMember:
        final content = event.content;
        final membership = content['membership'];
        final prevContent = event.prevContent;
        final prevMembership = prevContent?['membership'];

        if (membership == 'join') {
          // Check for profile changes (displayname/avatar)
          if (prevMembership == 'join') {
            final newName = content['displayname'];
            final oldName = prevContent?['displayname'];
            final newAvatar = content['avatar_url'];
            final oldAvatar = prevContent?['avatar_url'];

            if (newName != oldName && newName != null) {
              return '$oldName changed their name to $newName';
            }
            if (newAvatar != oldAvatar && newAvatar != null) {
              return '$senderName changed their profile picture';
            }
            return null; // No relevant change
          }
          return '$senderName joined the group';
        } else if (membership == 'leave') {
          if (prevMembership == 'invite') {
            return '$senderName rejected the invitation';
          }
          // Distinguish leave vs kick vs ban
          // Usually stateKey is the user ID being affected.
          // If senderId != stateKey, someone else did it.
          final targetUserId = event.stateKey;
          if (targetUserId != event.senderId) {
            // Kicked/Banned
            // Check reason?
            final reason = content['reason'];
            final action = membership == 'ban' ? 'banned' : 'kicked';
            // We need to resolve target display name? (hard without store)
            return '$senderName $action $targetUserId ${reason != null ? '($reason)' : ''}';
          }
          return '$senderName left the group';
        } else if (membership == 'invite') {
          final targetUserId = event.stateKey;
          return '$senderName invited $targetUserId';
        } else if (membership == 'ban') {
          final targetUserId = event.stateKey;
          return '$senderName banned $targetUserId';
        }
        break;

      case EventTypes.RoomName:
        final newName = event.content['name'];
        return '$senderName changed the group name to "$newName"';

      case EventTypes.RoomTopic:
        final newTopic = event.content['topic'];
        return '$senderName changed the group topic to "$newTopic"';

      case 'm.room.encryption':
        return 'Messages in this chat are now end-to-end encrypted.';

      case EventTypes.RoomCreate:
        final creator = event.senderId;
        return '$creator created the group';
    }
    return null;
  }
}
