import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:matrix/matrix.dart';
import 'package:monochat/core/utils/date_formats.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/room_list_controller.dart';
import 'package:monochat/controllers/space_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/screens/chat_screen.dart';
import 'package:monochat/ui/screens/new_chat_screen.dart';
import 'package:monochat/ui/screens/profile_screen.dart';
import 'package:monochat/ui/screens/space_view_screen.dart';
import 'package:monochat/ui/widgets/key_verification_dialog.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  StreamSubscription? _verificationSubscription;
  Client? _client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newClient = context.read<AuthController>().client;
    if (_client != newClient) {
      _verificationSubscription?.cancel();
      _client = newClient;
      if (_client != null) {
        _verificationSubscription = _client!.onKeyVerificationRequest.stream
            .listen((request) {
              if (mounted) {
                request.onUpdate = null;
                KeyVerificationDialog.show(context, request);
              }
            });
      }
    }
  }

  @override
  void dispose() {
    _verificationSubscription?.cancel();
    super.dispose();
  }

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
              const CupertinoActivityIndicator(),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.syncing,
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ],
          ),
        ),
      );
    }

    // If a space is active, show SpaceViewScreen - REMOVED
    // We now use standard navigation push for spaces.

    // Filter rooms - include spaces in the list now
    final rooms = controller.sortedRooms;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                // Room list
                Expanded(
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    cacheExtent: 350,
                    slivers: [
                      CupertinoSliverNavigationBar(
                        largeTitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.chatsTitle),
                            if (controller.isOffline)
                              const Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.wifi_slash,
                                      size: 16,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'You are offline',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: CupertinoColors.secondaryLabel,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                          child: _CurrentUserAvatar(client: client),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: CupertinoColors.separator.withValues(
                              alpha: 0.3,
                            ),
                            width: 0.5,
                          ),
                        ),
                      ),
                      if (rooms.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.chat_bubble_2,
                                  size: 64,
                                  color: palette.secondaryText.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No chats yet',
                                  style: TextStyle(
                                    color: palette.secondaryText,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CupertinoButton(
                                  child: const Text('Start a new chat'),
                                  onPressed: () {
                                    final spaceController = context
                                        .read<SpaceController>();
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        fullscreenDialog: true,
                                        builder: (_) =>
                                            ChangeNotifierProvider.value(
                                              value: spaceController,
                                              child: const NewChatScreen(),
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom + 100,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              if (index.isOdd) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 82),
                                  child: Container(
                                    height: 0.5,
                                    color: palette.separator.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                );
                              }
                              final room = rooms[index ~/ 2];
                              return _RoomTile(
                                key: ValueKey(room.id),
                                room: room,
                              );
                            }, childCount: rooms.length * 2 - 1),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 80,
            right: 24,
            child: GestureDetector(
              onTap: () {
                final spaceController = context.read<SpaceController>();
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: spaceController,
                      child: const NewChatScreen(),
                    ),
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
                      color: CupertinoColors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.add,
                  color: CupertinoColors.white,
                  size: 28,
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
  // NOTE: No per-tile sync subscription needed!
  // RoomListController already listens to sync stream and calls notifyListeners(),
  // which rebuilds the entire room list including this tile.

  String _getMessagePreview(Event? event, Room room) {
    if (room.isSpace) return 'Space';
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

    // Logic + Fix for self-messages
    // 1. isUnread includes notificationCount > 0 OR markedUnread
    // 2. Override if the last message is sent by me
    var isUnread = widget.room.isUnread;
    var count = widget.room.notificationCount;

    if (lastEvent?.senderId == widget.room.client.userID) {
      isUnread = false;
      count = 0;
    }

    final timeStr = lastEvent != null
        ? AppDateFormats.hourMinute.format(lastEvent.originServerTs)
        : '';

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        if (widget.room.isSpace) {
          // Navigate to Space View
          final spaceController = context.read<SpaceController>();
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: spaceController,
                child: SpaceViewScreen(
                  spaceId: widget.room.id,
                  onBack: spaceController.clearActiveSpace,
                ),
              ),
            ),
          );
          return;
        }

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
      onLongPress: () {
        final isPinned = widget.room.tags.containsKey('m.favourite');
        showCupertinoModalPopup(
          context: context,
          builder: (context) => CupertinoActionSheet(
            actions: [
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    if (isPinned) {
                      await widget.room.removeTag('m.favourite');
                    } else {
                      await widget.room.addTag('m.favourite', order: 0.5);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showCupertinoDialog(
                        context: context,
                        builder: (c) => CupertinoAlertDialog(
                          title: const Text('Error'),
                          content: Text('Failed to update pin status: $e'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () => Navigator.pop(c),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  isPinned
                      ? AppLocalizations.of(context)?.unpinChat ?? 'Unpin Chat'
                      : AppLocalizations.of(context)?.pinChat ?? 'Pin Chat',
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ),
        );
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
              borderRadius: widget.room.isSpace ? 12 : null,
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
                        child: Row(
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
                            if (widget.room.isSpace) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.secondaryText.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Space',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            if (widget.room.tags.containsKey(
                              'm.favourite',
                            )) ...[
                              const SizedBox(width: 4),
                              Icon(
                                CupertinoIcons.pin_fill,
                                size: 14,
                                color: palette.secondaryText,
                              ),
                            ],
                          ],
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

class _CurrentUserAvatar extends StatefulWidget {
  final Client client;

  const _CurrentUserAvatar({super.key, required this.client});

  @override
  State<_CurrentUserAvatar> createState() => _CurrentUserAvatarState();
}

class _CurrentUserAvatarState extends State<_CurrentUserAvatar> {
  Uri? _avatarUrl;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (widget.client.userID == null) return;
    try {
      final profile = await widget.client.fetchOwnProfile();
      if (mounted) {
        setState(() {
          _avatarUrl = profile.avatarUrl;
          _displayName = profile.displayName;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.client.userID;
    return MatrixAvatar(
      avatarUrl: _avatarUrl,
      name: _displayName ?? userId,
      client: widget.client,
      size: 32,
    );
  }
}
