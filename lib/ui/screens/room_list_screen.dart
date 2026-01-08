import 'package:flutter/cupertino.dart';

import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/room_list_controller.dart';
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
      child: CustomScrollView(
        cacheExtent: 350,
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(AppLocalizations.of(context)!.chatsTitle),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add, size: 24),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const NewChatScreen(),
                  ),
                );
              },
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.person_crop_circle, size: 26),
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
                    color: CupertinoColors.separator.withValues(alpha: 0.5),
                  ),
                );
              }
              final room = rooms[index ~/ 2];
              return _RoomTile(key: ValueKey(room.id), room: room);
            }, childCount: rooms.isNotEmpty ? rooms.length * 2 - 1 : 0),
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
      final bool hasRelevantUpdate =
          (syncUpdate.rooms?.join?.containsKey(roomId) ?? false) ||
          (syncUpdate.rooms?.invite?.containsKey(roomId) ?? false) ||
          (syncUpdate.rooms?.leave?.containsKey(roomId) ?? false) ||
          // Also check ephemeral for typing/read receipts if needed later,
          // but for now join/invite/leave covers messages/counts.
          false;

      if (hasRelevantUpdate && mounted) {
        setState(() {});
      }
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  Widget build(BuildContext context) {
    final lastEvent = widget.room.lastEvent;

    // FluffyChat Logic:
    // 1. isUnread includes notificationCount > 0 OR markedUnread
    final bool isUnread = widget.room.isUnread;
    final int count = widget.room.notificationCount;

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
            ? CupertinoColors.systemGrey4.withValues(alpha: 0.5)
            : CupertinoColors.systemBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            MatrixAvatar(
              avatarUrl: widget.room.avatar,
              name: widget.room.getLocalizedDisplayname(),
              client: widget.room.client,
              size: 58,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                            letterSpacing: -0.4,
                            color: CupertinoColors.label,
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
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastEvent?.body ?? 'No messages',
                          style: TextStyle(
                            fontSize: 15,
                            color: isUnread
                                ? CupertinoColors.label
                                : CupertinoColors.secondaryLabel,
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
                            color: CupertinoColors.activeBlue,
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
                          decoration: const BoxDecoration(
                            color: CupertinoColors.activeBlue,
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
