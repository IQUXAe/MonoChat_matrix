import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/room_list_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/ui/screens/chat_screen.dart';
import 'package:monochat/ui/screens/new_chat_screen.dart';
import 'package:monochat/ui/screens/profile_screen.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:monochat/l10n/generated/app_localizations.dart';

class RoomListScreen extends StatelessWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RoomListController>();
    final client = context.watch<AuthController>().client;
    final palette = context.watch<ThemeController>().palette;

    if (client == null || controller.isPreloading) {
      return CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.syncing,
                style: TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ],
          ),
        ),
      );
    }

    final rooms = controller.sortedRooms;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          CustomScrollView(
            cacheExtent: 350,
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(AppLocalizations.of(context)!.chatsTitle),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 26,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 82),
                      child: Container(
                        height: 0.5,
                        color: palette.separator.withValues(alpha: 0.5),
                      ),
                    );
                  }
                  final room = rooms[index ~/ 2];
                  return _RoomTile(key: ValueKey(room.id), room: room);
                }, childCount: rooms.isNotEmpty ? rooms.length * 2 - 1 : 0),
              ),
            ],
          ),
          Positioned(
            bottom: 80,
            right: 24,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const NewChatScreen(),
                  ),
                );
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/plus.svg',
                  colorFilter: const ColorFilter.mode(
                    CupertinoColors.white,
                    BlendMode.srcIn,
                  ),
                  width: 24,
                  height: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatefulWidget {
  final Room room;
  const _RoomTile({super.key, required this.room});

  @override
  State<_RoomTile> createState() => _RoomTileState();
}

class _RoomTileState extends State<_RoomTile> {
  bool _isPressed = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_RoomTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.room.id != oldWidget.room.id ||
        widget.room.client != oldWidget.room.client) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    // Determine which client to listen to
    final client = widget.room.client;

    _subscription = client.onSync.stream.listen((syncUpdate) {
      final roomId = widget.room.id;
      // Filter updates to only this room to avoid unnecessary rebuilds.
      // This maintains "Best Practice" performance while ensuring the "instant"
      // update behavior the user desires for the specific chat events.
      final roomUpdate = syncUpdate.rooms?.join?[roomId];
      final bool hasRelevantUpdate =
          (roomUpdate != null &&
              (roomUpdate.timeline != null ||
                  roomUpdate.state != null ||
                  roomUpdate.ephemeral != null ||
                  roomUpdate.accountData != null ||
                  roomUpdate.unreadNotifications != null)) ||
          (syncUpdate.rooms?.invite?.containsKey(roomId) ?? false) ||
          (syncUpdate.rooms?.leave?.containsKey(roomId) ?? false);

      if (hasRelevantUpdate && mounted) {
        setState(() {});
      }
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  String _getMessagePreview(Event? event, Room room) {
    if (event == null) return 'No messages';

    final isMe = event.senderId == room.client.userID;
    final senderPrefix = isMe ? 'You: ' : '';

    // Handle different message types
    switch (event.messageType) {
      case MessageTypes.Image:
        return '$senderPrefix📷 Photo';
      case MessageTypes.Video:
        return '$senderPrefix🎬 Video';
      case MessageTypes.Audio:
        return '$senderPrefix🎵 Audio';
      case MessageTypes.File:
        return '$senderPrefix📎 File';
      case MessageTypes.Sticker:
        return '$senderPrefix🌟 Sticker';
      case MessageTypes.Location:
        return '$senderPrefix📍 Location';
      default:
        break;
    }

    // For text messages, clean up reply format
    var body = event.body;

    // Remove Matrix reply format (> <@user:server> message\n\n)
    if (body.startsWith('> <@')) {
      final newlineIndex = body.indexOf('\n\n');
      if (newlineIndex != -1 && newlineIndex < body.length - 2) {
        body = body.substring(newlineIndex + 2);
      }
    }

    // Remove m.relates_to reply indicator
    if (body.startsWith('> ')) {
      final lines = body.split('\n');
      // Skip lines starting with > and empty line after
      var startIndex = 0;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('> ') || lines[i].isEmpty) {
          startIndex = i + 1;
        } else {
          break;
        }
      }
      if (startIndex < lines.length) {
        body = lines.sublist(startIndex).join('\n');
      }
    }

    return '$senderPrefix$body';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final lastEvent = widget.room.lastEvent;

    // FluffyChat Logic + Fix for self-messages
    // 1. isUnread includes notificationCount > 0 OR markedUnread
    // 2. Override if the last message is sent by me
    bool isUnread = widget.room.isUnread;
    int count = widget.room.notificationCount;

    if (lastEvent?.senderId == widget.room.client.userID) {
      isUnread = false;
      count = 0;
    }

    final timeStr = lastEvent != null
        ? DateFormat('HH:mm').format(lastEvent.originServerTs)
        : '';

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        // Fix for counter bugs: explicitly mark as read on the server side
        // when tapping the chat. This ensures the count resets correctly.
        final lastEventId = widget.room.lastEvent?.eventId;
        if (lastEventId != null && widget.room.notificationCount > 0) {
          widget.room.setReadMarker(lastEventId, mRead: lastEventId);
        }

        // Clear manual 'Mark as unread' flag if present
        if (widget.room.isUnread) {
          widget.room.markUnread(false);
        }

        if (context.mounted) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => ChatScreen(room: widget.room),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isPressed
            ? palette.inputBackground.withValues(alpha: 0.5)
            : palette.scaffoldBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            MatrixAvatar(
              avatarUrl: widget.room.avatar,
              name: widget.room.getLocalizedDisplayname(),
              client: widget.room.client,
              size: 58,
              userId:
                  widget.room.directChatMatrixID, // Show online status for DMs
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.room.getLocalizedDisplayname(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                            letterSpacing: -0.4,
                            color: palette.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 14,
                          color: isUnread
                              ? palette.primary
                              : palette.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getMessagePreview(lastEvent, widget.room),
                          style: TextStyle(
                            fontSize: 15,
                            color: isUnread
                                ? palette.text
                                : palette.secondaryText,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Badge Logic
                      if (count > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: const BoxConstraints(minWidth: 24),
                          child: Center(
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else if (isUnread)
                        // Manual unread dot
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: palette.primary,
                            shape: BoxShape.circle,
                          ),
                        ),

                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: CupertinoColors.systemGrey3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
