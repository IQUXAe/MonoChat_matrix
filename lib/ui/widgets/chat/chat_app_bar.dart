import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/ui/screens/user_verification_screen.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:monochat/ui/widgets/presence_builder.dart';
import 'package:monochat/ui/screens/room_details_screen.dart';

import 'package:monochat/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

class ChatAppBar extends StatelessWidget {
  final Room room;
  final Client client;

  const ChatAppBar({super.key, required this.room, required this.client});

  void _openRoomDetails(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => RoomDetailsScreen(room: room, client: client),
      ),
    );
  }

  void _showEvaluationSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Encryption'),
        message: Text(
          room.encrypted
              ? 'Messages in this chat are end-to-end encrypted.${room.isDirectChat ? " Verify this user to ensure security." : ""}'
              : 'Messages in this chat are NOT encrypted. You can enable encryption, but it cannot be disabled later.',
        ),
        actions: [
          if (room.encrypted &&
              room.isDirectChat &&
              room.directChatMatrixID != null)
            CupertinoActionSheetAction(
              child: const Text('Verify User'),
              onPressed: () {
                Navigator.pop(context);
                _startUserVerification(context, room.directChatMatrixID!);
              },
            ),
          if (!room.encrypted)
            CupertinoActionSheetAction(
              child: const Text('Enable Encryption'),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await room.enableEncryption();
                } catch (e) {
                  if (context.mounted) {
                    showCupertinoDialog(
                      context: context,
                      builder: (c) => CupertinoAlertDialog(
                        title: const Text('Error'),
                        content: Text(e.toString()),
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
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ),
    );
  }

  Future<void> _startUserVerification(
    BuildContext context,
    String userId,
  ) async {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => UserVerificationScreen(client: client, userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final palette = context.watch<ThemeController>().palette;
    final isEncrypted = room.encrypted;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          // Ensure bar covers status bar area
          height: 60 + topPadding,
          padding: EdgeInsets.only(top: topPadding, left: 8, right: 8),
          decoration: BoxDecoration(
            color: palette.glassBackground,
            border: Border(
              bottom: BorderSide(
                color: palette.separator.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(CupertinoIcons.back, size: 28),
              ),
              const Gap(4),

              // Tappable profile area
              Expanded(
                child: GestureDetector(
                  onTap: () => _openRoomDetails(context),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      MatrixAvatar(
                        avatarUrl: room.avatar,
                        name: room.getLocalizedDisplayname(),
                        client: client,
                        size: 40,
                        userId: room.directChatMatrixID,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.getLocalizedDisplayname(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            if (room.directChatMatrixID != null)
                              PresenceBuilder(
                                client: client,
                                userId: room.directChatMatrixID!,
                                builder: (context, presence) {
                                  if (presence == null ||
                                      presence.presence ==
                                          PresenceType.offline) {
                                    return const SizedBox.shrink();
                                  }

                                  String status = '';
                                  Color color = CupertinoColors.systemGrey;

                                  if (presence.presence ==
                                      PresenceType.online) {
                                    status = 'Online';
                                    color = CupertinoColors.activeGreen;
                                  } else if (presence.presence ==
                                      PresenceType.unavailable) {
                                    status = 'Away';
                                    color = CupertinoColors.systemYellow;
                                  } else {
                                    return const SizedBox.shrink();
                                  }

                                  return Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              )
                            else if (!room.isDirectChat)
                              Text(
                                '${room.summary.mJoinedMemberCount ?? 0} members',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Encryption Lock
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: () => _showEvaluationSheet(context),
                        child: Icon(
                          isEncrypted
                              ? CupertinoIcons.lock_fill
                              : CupertinoIcons.lock_open_fill,
                          size: 18,
                          color: isEncrypted
                              ? CupertinoColors.activeGreen
                              : CupertinoColors.systemRed,
                        ),
                      ),

                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: palette.secondaryText,
                      ),
                      const Gap(8),
                    ],
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
