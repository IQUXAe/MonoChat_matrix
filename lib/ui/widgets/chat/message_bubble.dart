import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart'
    show
        Colors,
        Divider; // Icons needed for some menu items if CupertinoIcons missing

import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/chat_controller.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';
import 'package:monochat/ui/widgets/full_screen_image_viewer.dart';
import 'package:monochat/ui/widgets/chat/video_bubble.dart';
import 'package:monochat/ui/widgets/chat/file_bubble.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/ui/theme/app_palette.dart';
import 'package:monochat/ui/dialogs/user_profile_dialog.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

class MessageBubble extends StatefulWidget {
  final Event event;
  final bool isMe;
  final bool showTail;
  final bool isFirstInGroup;
  final Client client;
  final Timeline timeline;

  const MessageBubble({
    super.key,
    required this.event,
    required this.isMe,
    required this.showTail,
    this.isFirstInGroup =
        true, // Default to true for backward compatibility until ChatScreen provided
    required this.client,
    required this.timeline,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final Set<String> _optimisticAdd = {};
  final Set<String> _optimisticRemove = {};

  final GlobalKey _bubbleKey = GlobalKey();

  void _toggleReaction(String key) {
    if (!mounted) return;

    // Optimistic Update
    setState(() {
      if (_optimisticAdd.contains(key)) {
        _optimisticAdd.remove(key);
      } else if (_optimisticRemove.contains(key)) {
        _optimisticRemove.remove(key);
      } else {
        // Check actual state from model
        final allReactionEvents = widget.event.aggregatedEvents(
          widget.timeline,
          RelationshipTypes.reaction,
        );
        final hasReacted = allReactionEvents.any(
          (e) =>
              e.senderId == widget.client.userID &&
              e.content.tryGetMap<String, dynamic>('m.relates_to')?['key'] ==
                  key,
        );

        if (hasReacted) {
          _optimisticRemove.add(key);
        } else {
          _optimisticAdd.add(key);
        }
      }
    });

    // Actual API Call
    final allReactionEvents = widget.event.aggregatedEvents(
      widget.timeline,
      RelationshipTypes.reaction,
    );
    final myReaction = allReactionEvents.firstWhereOrNull(
      (e) =>
          e.senderId == widget.client.userID &&
          e.content.tryGetMap<String, dynamic>('m.relates_to')?['key'] == key,
    );

    Future<void> action;
    if (myReaction != null) {
      if (_optimisticAdd.contains(key)) {
        action = Future.value(); // Race handling
      } else {
        action = myReaction.redactEvent();
      }
    } else {
      if (_optimisticRemove.contains(key)) {
        action = Future.value();
      } else {
        action = widget.event.room.sendReaction(widget.event.eventId, key);
      }
    }

    action.then((_) {
      if (mounted) {
        // Clear optimistic state once confirmed (optional, but keeps state clean)
        // Actually, wait for sync update to clear it?
        // If we clear it now, it might flicker back if sync hasn't arrived.
        // Better to keep optimistic state until we see the change in 'widget.event'.
        // Implementing 'listener' on event is hard.
        // For now, let's keep it until view refresh or manual cleanup.
        // Simple cleanup:
        /*
         setState(() {
            _optimisticAdd.remove(key);
            _optimisticRemove.remove(key);
         });
         */
      }
    });
  }

  void _showCustomContextMenu() {
    final renderBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final palette = Provider.of<ThemeController>(
      context,
      listen: false,
    ).palette;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _MessageMenuOverlay(
              event: widget.event,
              isMe: widget.isMe,
              showTail: widget.showTail,
              isFirstInGroup: widget.isFirstInGroup,
              client: widget.client,
              timeline: widget.timeline,
              bubbleOffset: offset,
              bubbleSize: size,
              palette: palette,
              optimisticAdd: _optimisticAdd,
              optimisticRemove: _optimisticRemove,
              onReactionToggle: (key) {
                _toggleReaction(key);
                HapticFeedback.lightImpact();
                Navigator.pop(context); // Close menu after reaction
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatController = context
        .watch<ChatController?>(); // nullable if not provided?
    final isSelectionMode = chatController?.isSelectionMode ?? false;
    final isSelected =
        chatController?.selectedEventIds.contains(widget.event.eventId) ??
        false;
    final palette = context.watch<ThemeController>().palette;

    // We used to wrap the content in GestureDetector.
    // Now we need the GestureDetector to cover the whole area relevant to the message.

    Widget content = _MessageContent(
      key: _bubbleKey,
      event: widget.event,
      isMe: widget.isMe,
      showTail: widget.showTail,
      isFirstInGroup: widget.isFirstInGroup,
      client: widget.client,
      timeline: widget.timeline,
      optimisticAdd: _optimisticAdd,
      optimisticRemove: _optimisticRemove,
      onReactionTap: _toggleReaction,
    );

    // Selection Highlight
    if (isSelected) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    // Check for System/State events
    final isSystemEvent =
        widget.event.type == EventTypes.RoomMember ||
        widget.event.type == EventTypes.RoomName ||
        widget.event.type == EventTypes.RoomTopic ||
        widget.event.type == EventTypes.RoomCreate ||
        widget.event.type == 'm.room.encryption';

    if (isSystemEvent) {
      return _buildSystemNotice(context, palette);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (isSelectionMode && chatController != null) {
          chatController.toggleSelection(widget.event.eventId);
        } else {
          // Standard tap behavior logic
          final msgType = widget.event.messageType;
          if (msgType == MessageTypes.Image || msgType == MessageTypes.Video) {
            // Let child widget handle tap (e.g. open viewer) if strictly needed
            // But our GestureDetector here steals taps.
            // We can use the 'Child' logic for Image, but wait.
            // If I tap "text", I want menu.
            // If I tap "image", I want viewer.
            // Solution: internal gesture detectors in `_MessageContent` handle media taps.
            // This outer detector handles "bubble background" taps which for Text bubbles is the content.
            _showCustomContextMenu();
          } else {
            _showCustomContextMenu();
          }
        }
      },
      onLongPress: () {
        if (chatController != null) {
          // Always toggle selection on long press
          chatController.toggleSelection(widget.event.eventId);
          HapticFeedback.mediumImpact();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 2,
        ), // small margin for selection visibility
        child: content,
      ),
    );
  }

  Widget _buildSystemNotice(BuildContext context, AppPalette palette) {
    String text = '';
    final senderName = widget.event.senderFromMemoryOrFallback
        .calcDisplayname();

    final type = widget.event.type;
    final content = widget.event.content;
    final prevContent = widget.event.prevContent;

    if (type == EventTypes.RoomMember) {
      final membership = content.tryGet<String>('membership');
      final prevMembership = prevContent?.tryGet<String>('membership');
      final stateKey = widget.event.stateKey;
      final targetId = stateKey;

      String targetName = targetId ?? '';
      if (targetId == widget.client.userID) {
        targetName = 'You';
      } else if (targetId == widget.event.senderId) {
        targetName = senderName;
      } else {
        targetName =
            content.tryGet<String>('displayname') ?? targetId ?? 'Someone';
      }

      if (membership == 'join') {
        if (prevMembership == 'join') {
          // Profile update
          final newName = content.tryGet<String>('displayname');
          final oldName = prevContent?.tryGet<String>('displayname');
          final newAvatar = content.tryGet<String>('avatar_url');
          final oldAvatar = prevContent?.tryGet<String>('avatar_url');

          if (newName != oldName && newName != null && oldName != null) {
            text = '$senderName changed their name to $newName';
          } else if (newAvatar != oldAvatar) {
            text = '$senderName changed their avatar';
          } else {
            text = '$senderName updated their profile';
          }
        } else {
          // Joined
          if (targetId == widget.event.senderId) {
            text = '$senderName joined the chat';
          } else {
            text = '$targetName joined the chat';
          }
        }
      } else if (membership == 'leave') {
        if (targetId == widget.event.senderId) {
          text = '$senderName left the chat';
        } else if (prevMembership == 'invite') {
          if (targetId == widget.event.senderId) {
            text = '$senderName rejected the invitation';
          } else {
            text = '$senderName rejected the invitation for $targetName';
          }
        } else if (prevMembership == 'join') {
          if (targetId != widget.event.senderId) {
            text = '$targetName was kicked by $senderName';
          } else {
            text = '$senderName left';
          }
        } else if (prevMembership == 'ban') {
          text = '$targetName was unbanned by $senderName';
        }
      } else if (membership == 'invite') {
        text = '$senderName invited $targetName';
      } else if (membership == 'ban') {
        text = '$targetName was banned by $senderName';
      }
    } else if (type == EventTypes.RoomName) {
      final name = content.tryGet<String>('name');
      text = '$senderName changed the room name to "$name"';
    } else if (type == EventTypes.RoomTopic) {
      final topic = content.tryGet<String>('topic');
      text = '$senderName changed the topic to "$topic"';
    } else if (type == EventTypes.RoomCreate) {
      text = '$senderName created the group';
    } else if (type == 'm.room.encryption') {
      text = 'Encryption enabled';
    }

    if (text.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
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
}

class _MessageContent extends StatelessWidget {
  final Event event;
  final bool isMe;
  final bool showTail;
  final bool isFirstInGroup;
  final Client client;
  final Timeline timeline;
  final Set<String> optimisticAdd;
  final Set<String> optimisticRemove;
  final Function(String) onReactionTap;

  const _MessageContent({
    super.key,
    required this.event,
    required this.isMe,
    required this.showTail,
    this.isFirstInGroup = true,
    required this.client,
    required this.timeline,
    required this.optimisticAdd,
    required this.optimisticRemove,
    required this.onReactionTap,
  });

  BorderRadius _getBorderRadius() {
    return BorderRadius.only(
      topLeft: Radius.circular(isMe ? 20 : (isFirstInGroup ? 20 : 5)),
      topRight: Radius.circular(isMe ? (isFirstInGroup ? 20 : 5) : 20),
      bottomLeft: Radius.circular(isMe ? 20 : (showTail ? 5 : 20)),
      bottomRight: Radius.circular(isMe ? (showTail ? 5 : 20) : 20),
    );
  }

  void _showUserProfile(BuildContext context, Event event, Client client) {
    final sender = event.senderFromMemoryOrFallback;
    UserProfileDialog.show(
      context: context,
      profile: Profile(
        userId: sender.id,
        displayName: sender.displayName,
        avatarUrl: sender.avatarUrl,
      ),
      client: client,
      room: event.room,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final msgType = event.messageType;
    final isImage = msgType == MessageTypes.Image;

    Widget contentBubble;

    if (isImage) {
      contentBubble = _buildImageBubble(context, palette);
    } else if (event.type == 'm.key.verification.request' ||
        msgType == 'm.key.verification.request') {
      contentBubble = _buildVerificationRequestBubble(context, palette);
    } else if (msgType == MessageTypes.Video) {
      contentBubble = VideoBubble(event: event, isMe: isMe, client: client);
    } else if (msgType == MessageTypes.File) {
      contentBubble = Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: showTail ? 12 : 3),
          child: FileBubble(event: event, isMe: isMe),
        ),
      );
    } else {
      final isEncrypted = event.type == EventTypes.Encrypted;
      contentBubble = Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: showTail ? 12 : 3),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe && showTail)
                GestureDetector(
                  onTap: () => _showUserProfile(context, event, client),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, bottom: 4),
                    child: Text(
                      event.senderFromMemoryOrFallback.calcDisplayname(),
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isEncrypted
                      ? palette.inputBackground.withValues(alpha: 0.5)
                      : (isMe ? palette.primary : palette.inputBackground),
                  borderRadius: _getBorderRadius(),
                ),
                child: _buildContent(context, palette),
              ),
              if (showTail)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 4, right: 4),
                  child: Text(
                    DateFormat('HH:mm').format(event.originServerTs),
                    style: TextStyle(
                      fontSize: 10,
                      color: CupertinoColors.systemGrey.withOpacity(0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [contentBubble, _buildReactions(context, palette)],
    );
  }

  Widget _buildContent(BuildContext context, AppPalette palette) {
    final isEncrypted = event.type == EventTypes.Encrypted;

    if (isEncrypted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.lock_fill,
            size: 14,
            color: CupertinoColors.systemGrey,
          ),
          Gap(6),
          Text(
            AppLocalizations.of(context)!.waitingForMessage,
            style: TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // Check for reply
    final relation = event.content.tryGetMap<String, dynamic>('m.relates_to');
    final isReply = relation?['m.in_reply_to'] != null;

    String body = event.body;
    Widget? replyPreview;

    if (isReply) {
      // Strip fallback
      // Format: "> <@user:server> quoted message\n\nActual message"
      final lines = body.split('\n');
      if (lines.isNotEmpty && lines.first.startsWith('>')) {
        int contentStartIndex = 0;
        bool inQuote = true;
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('>')) {
            inQuote = true;
          } else if (lines[i].trim().isEmpty && inQuote) {
            contentStartIndex = i + 1;
            inQuote = false;
            break;
          }
        }
        if (contentStartIndex < lines.length) {
          body = lines.sublist(contentStartIndex).join('\n').trim();
        }
      }

      // Build preview
      // We need the replied-to event. It might be in the timeline or we might need to fetch it.
      // For now, let's try to query the timeline for the eventId.
      final replyEventId = relation!['m.in_reply_to']['event_id'];
      final replyEvent = timeline.events.firstWhereOrNull(
        (e) => e.eventId == replyEventId,
      );

      if (replyEvent != null) {
        replyPreview = _buildReplyPreview(context, replyEvent, palette);
      } else {
        // Event not in current timeline chunk?
        // Show skeleton or just "Replying to..."
        // Ideally we should resolve it, but synchronous build can't async fetch.
        // Just show a placeholder or try to use 'relationshipEvent' properties if SDK resolved them.
        replyPreview = _buildReplyPreviewPlaceholder(context, palette);
      }
    }

    final textWidget = Text(
      body,
      style: TextStyle(
        color: isMe ? CupertinoColors.white : palette.text,
        fontSize: 17,
        height: 1.2,
        letterSpacing: -0.2,
      ),
    );

    if (replyPreview != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [replyPreview, const Gap(4), textWidget],
      );
    }

    return textWidget;
  }

  Widget _buildReplyPreview(
    BuildContext context,
    Event replyEvent,
    AppPalette palette,
  ) {
    final senderName = replyEvent.senderFromMemoryOrFallback.calcDisplayname();

    // Determine colors based on whether this is own message
    final accentColor = isMe
        ? CupertinoColors.white.withValues(alpha: 0.7)
        : palette.primary;
    final textColor = isMe
        ? CupertinoColors.white.withValues(alpha: 0.85)
        : palette.text;
    final bgColor = isMe
        ? CupertinoColors.white.withValues(alpha: 0.15)
        : palette.separator.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.only(left: 2),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(8),
          // Content
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: accentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(2),
                  Text(
                    replyEvent.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreviewPlaceholder(
    BuildContext context,
    AppPalette palette,
  ) {
    final accentColor = isMe
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : palette.primary.withValues(alpha: 0.5);
    final bgColor = isMe
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : palette.separator.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.only(left: 2),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Reply to message...',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: isMe
                    ? CupertinoColors.white.withValues(alpha: 0.6)
                    : palette.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBubble(BuildContext context, AppPalette palette) {
    final bool isEncrypted = event.content['file'] is Map;
    final String? uriStr = event.content.tryGet<String>('url');
    final Uri? uri = (uriStr != null && !isEncrypted)
        ? Uri.tryParse(uriStr)
        : null;

    if (!isEncrypted && uri == null) return const SizedBox.shrink();

    final Map? info = event.content['info'] as Map?;
    final int? metaW = info?['w'] as int?;
    final int? metaH = info?['h'] as int?;

    double? width;
    double? height;
    double aspectRatio = 1.0;

    if (metaW != null && metaH != null && metaW > 0 && metaH > 0) {
      aspectRatio = metaW / metaH;
      final double maxWidth = MediaQuery.of(context).size.width * 0.70;
      final double maxHeight = 400.0;

      if (aspectRatio > 1) {
        width = (metaW < maxWidth) ? metaW.toDouble() : maxWidth;
        height = width / aspectRatio;
      } else {
        height = (metaH < maxHeight) ? metaH.toDouble() : maxHeight;
        width = height * aspectRatio;

        if (width > maxWidth) {
          width = maxWidth;
          height = width / aspectRatio;
        }
      }
    } else {
      width = 240.0;
      height = 240.0;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: showTail ? 12 : 3),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe && showTail)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0, left: 12),
                child: Text(
                  event.senderFromMemoryOrFallback.calcDisplayname(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: _getBorderRadius(),
              child: GestureDetector(
                onTap: () async {
                  // Open image viewer directly.
                  // Consume tap so menu doesn't open?
                  // Yes.

                  final timeline = await event.room.getTimeline();
                  final imageEvents = timeline.events
                      .where((e) => e.messageType == MessageTypes.Image)
                      .toList();

                  if (!imageEvents.any((e) => e.eventId == event.eventId)) {
                    imageEvents.add(event);
                  }

                  if (!context.mounted) return;

                  int initialIndex = imageEvents.indexWhere(
                    (e) => e.eventId == event.eventId,
                  );
                  if (initialIndex == -1) initialIndex = 0;

                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => FullScreenImageViewer(
                        images: imageEvents,
                        initialIndex: initialIndex,
                        client: client,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: width,
                  height: height,
                  color: palette.inputBackground,
                  child: MxcImage(
                    uri: uri,
                    client: client,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                    event: event,
                    isThumbnail: true,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0, right: 8, left: 8),
              child: Text(
                DateFormat('HH:mm').format(event.originServerTs),
                style: const TextStyle(
                  fontSize: 10,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationRequestBubble(
    BuildContext context,
    AppPalette palette,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: showTail ? 12 : 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.inputBackground,
            borderRadius: _getBorderRadius(),
            border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.shield_fill,
                color: palette.primary,
                size: 20,
              ),
              const Gap(8),
              Flexible(
                child: Text(
                  isMe ? 'Verification request sent' : 'Verification requested',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactions(BuildContext context, AppPalette palette) {
    final allReactionEvents = event.aggregatedEvents(
      timeline,
      RelationshipTypes.reaction,
    );

    final reactionMap = <String, _ReactionEntry>{};

    for (final e in allReactionEvents) {
      final key = e.content
          .tryGetMap<String, dynamic>('m.relates_to')
          ?.tryGet<String>('key');
      if (key != null) {
        if (!reactionMap.containsKey(key)) {
          reactionMap[key] = _ReactionEntry(key: key, count: 0, reacted: false);
        }
        reactionMap[key]!.count++;
        reactionMap[key]!.reacted |= e.senderId == client.userID;
      }
    }

    // Apply optimistic updates
    for (final key in optimisticAdd) {
      if (!reactionMap.containsKey(key)) {
        reactionMap[key] = _ReactionEntry(key: key, count: 0, reacted: false);
      }
      if (!reactionMap[key]!.reacted) {
        reactionMap[key]!.count++;
        reactionMap[key]!.reacted = true;
      }
    }
    for (final key in optimisticRemove) {
      if (reactionMap.containsKey(key) && reactionMap[key]!.reacted) {
        reactionMap[key]!.count--;
        reactionMap[key]!.reacted = false;
        if (reactionMap[key]!.count <= 0) {
          reactionMap.remove(key);
        }
      }
    }

    if (reactionMap.isEmpty) return const SizedBox.shrink();

    final reactionList = reactionMap.values.toList();
    reactionList.sort((a, b) => b.count - a.count > 0 ? 1 : -1);

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 0 : 12,
        right: isMe ? 12 : 0,
        bottom: 8,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: reactionList.map((entry) {
          final key = entry.key;
          final count = entry.count;
          final me = entry.reacted;

          return GestureDetector(
            onTap: () => onReactionTap(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: me
                    ? palette.primary.withValues(alpha: 0.15)
                    : palette.inputBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: me
                      ? palette.primary.withValues(alpha: 0.5)
                      : Colors
                            .transparent, // Cleaner look without border for others
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(key, style: const TextStyle(fontSize: 14)),
                  if (count > 1) ...[
                    const Gap(4),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        color: me ? palette.primary : palette.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MessageMenuOverlay extends StatefulWidget {
  final Event event;
  final bool isMe;
  final bool showTail;
  final bool isFirstInGroup;
  final Client client;
  final Timeline timeline;
  final Offset bubbleOffset;
  final Size bubbleSize;
  final AppPalette palette;
  final Set<String> optimisticAdd;
  final Set<String> optimisticRemove;
  final Function(String) onReactionToggle;

  const _MessageMenuOverlay({
    required this.event,
    required this.isMe,
    required this.showTail,
    this.isFirstInGroup = true,
    required this.client,
    required this.timeline,
    required this.bubbleOffset,
    required this.bubbleSize,
    required this.palette,
    required this.optimisticAdd,
    required this.optimisticRemove,
    required this.onReactionToggle,
  });

  @override
  State<_MessageMenuOverlay> createState() => _MessageMenuOverlayState();
}

class _MessageMenuOverlayState extends State<_MessageMenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate menu position
    final screenHeight = MediaQuery.of(context).size.height;
    final showAbove = widget.bubbleOffset.dy > screenHeight / 2;

    // Ensure bubble stays within screen bounds (horizontal)
    // widget.bubbleOffset should be correct as it's from GlobalKey.

    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: () {
            _controller.reverse().then((value) => Navigator.pop(context));
          },
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),

        // Static Message Clone
        Positioned(
          top: widget.bubbleOffset.dy,
          left: widget.bubbleOffset.dx,
          width: widget.bubbleSize.width,
          height: widget.bubbleSize.height,
          child: IgnorePointer(
            // Ignore taps on the static clone
            child: _MessageContent(
              event: widget.event,
              isMe: widget.isMe,
              showTail: widget.showTail,
              isFirstInGroup: widget.isFirstInGroup,
              client: widget.client,
              timeline: widget.timeline,
              optimisticAdd: widget.optimisticAdd,
              optimisticRemove: widget.optimisticRemove,
              onReactionTap: (_) {},
            ),
          ),
        ),

        // Menu
        Positioned(
          // Adjust vertical position to be above or below bubble
          top: showAbove
              ? null
              : widget.bubbleOffset.dy + widget.bubbleSize.height + 8,
          bottom: showAbove ? screenHeight - widget.bubbleOffset.dy + 8 : null,
          left: widget.isMe ? null : 20,
          right: widget.isMe ? 20 : null,
          // Limit width to avoid overflow
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: widget.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    _buildReactionMenu(context),
                    Gap(10),
                    _buildActionMenu(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReactionMenu(BuildContext context) {
    final quickReactions = ['❤️', '👍', '👎', '😂', '😮', '😢', '🔥'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: widget.palette.barBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // shrink to fit
        children: quickReactions.map((emoji) {
          final allReactionEvents = widget.event.aggregatedEvents(
            widget.timeline,
            RelationshipTypes.reaction,
          );
          var meReacted = allReactionEvents.any(
            (e) =>
                e.senderId == widget.client.userID &&
                e.content.tryGetMap<String, dynamic>('m.relates_to')?['key'] ==
                    emoji,
          );

          if (widget.optimisticAdd.contains(emoji)) meReacted = true;
          if (widget.optimisticRemove.contains(emoji)) meReacted = false;

          return GestureDetector(
            onTap: () {
              widget.onReactionToggle(emoji);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: meReacted
                    ? widget.palette.primary.withOpacity(0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: meReacted
                    ? Border.all(color: widget.palette.primary.withOpacity(0.5))
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: widget.palette.barBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionItem(context, 'Reply', CupertinoIcons.reply, () {
            Navigator.pop(context);
            // Reply action
          }),
          Divider(height: 1, color: widget.palette.separator.withOpacity(0.3)),
          _buildActionItem(
            context,
            'Copy',
            CupertinoIcons.doc_on_clipboard,
            () {
              Clipboard.setData(ClipboardData(text: widget.event.body));
              Navigator.pop(context);
            },
          ),
          Divider(height: 1, color: widget.palette.separator.withOpacity(0.3)),
          if (!widget.isMe) ...[
            _buildActionItem(
              context,
              'View Profile',
              CupertinoIcons.person_circle,
              () {
                Navigator.pop(context);
                final sender = widget.event.senderFromMemoryOrFallback;
                UserProfileDialog.show(
                  context: context,
                  profile: Profile(
                    userId: sender.id,
                    displayName: sender.displayName,
                    avatarUrl: sender.avatarUrl,
                  ),
                  client: widget.client,
                  room: widget.event.room,
                );
              },
            ),
            Divider(
              height: 1,
              color: widget.palette.separator.withOpacity(0.3),
            ),
          ],
          _buildActionItem(context, 'Delete', CupertinoIcons.delete, () {
            Navigator.pop(context);
            // Delete action
          }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isDestructive
                    ? CupertinoColors.destructiveRed
                    : widget.palette.text,
              ),
            ),
            Icon(
              icon,
              size: 18,
              color: isDestructive
                  ? CupertinoColors.destructiveRed
                  : widget.palette.text,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionEntry {
  final String key;
  int count;
  bool reacted;

  _ReactionEntry({
    required this.key,
    required this.count,
    required this.reacted,
  });
}
