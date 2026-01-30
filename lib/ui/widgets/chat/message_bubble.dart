import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';

import 'package:monochat/ui/dialogs/user_profile_dialog.dart';
import 'package:monochat/ui/widgets/chat/emoji_picker/reaction_picker_sheet.dart';
import 'package:monochat/ui/widgets/chat/file_bubble.dart';
import 'package:monochat/ui/widgets/chat/video_bubble.dart';
import 'package:monochat/ui/widgets/full_screen_image_viewer.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';
import 'package:provider/provider.dart';

import '../blur_hash.dart';

class MessageBubble extends StatelessWidget {
  final Event event;
  final bool isMe;
  final bool showTail;
  final bool isFirstInGroup;
  final Client client;
  final Timeline? timeline;
  final Function(String) onReplyTap;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MessageBubble({
    super.key,
    required this.event,
    required this.isMe,
    required this.showTail,
    required this.isFirstInGroup,
    required this.client,
    required this.timeline,
    required this.onReplyTap,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    // Determine bubble color
    // Use inputBackground for 'other' to ensure visibility in dark mode (2C2C2E vs 1C1C1E)
    // instead of systemGrey6 which might resolve to scaffold background.
    final bubbleColor = isMe ? palette.primary : palette.inputBackground;

    final textColor = isMe ? Colors.white : palette.text;

    // Bubble Alignment
    // final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;

    // Check for avatars (Group chat + Not Me)
    final showAvatar = !isMe && !event.room.isDirectChat;

    return Padding(
      // Apple-like spacing
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 2 : 1, // Tighter grouping
        bottom: 1,
        left: isMe ? 40 : (showAvatar ? 4 : 8),
        right: isMe ? 8 : 40,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar) ...[
            if (showTail)
              GestureDetector(
                onTap: () {
                  final user = event.senderFromMemoryOrFallback;
                  final profile = Profile(
                    userId: user.id,
                    displayName: user.displayName,
                    avatarUrl: user.avatarUrl,
                  );
                  UserProfileDialog.show(
                    context: context,
                    profile: profile,
                    client: client,
                    room: event.room,
                  );
                },
                child: MxcImage(
                  // Use sender's avatar, not event attachment
                  uri: event.senderFromMemoryOrFallback.avatarUrl,
                  client: client,
                  width: 30,
                  height: 30,
                  borderRadius: BorderRadius.circular(15),
                  isThumbnail: true,
                  placeholder: (_) => Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: palette.secondaryText.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        event.senderFromMemoryOrFallback
                                    .calcDisplayname()
                                    .isNotEmpty ==
                                true
                            ? event.senderFromMemoryOrFallback
                                  .calcDisplayname()[0]
                            : '?',
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 30),
            const Gap(8),
          ],
          CupertinoContextMenu(
            // Context Menu Actions (iOS Style)
            actions: [
              CupertinoContextMenuAction(
                child: const Text('Reply'),
                onPressed: () {
                  Navigator.pop(context);
                  onReply();
                },
              ),
              CupertinoContextMenuAction(
                child: const Text('Add Reaction'),
                onPressed: () {
                  Navigator.pop(context);
                  _showReactionPicker(context);
                },
              ),
              CupertinoContextMenuAction(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        event.room.sendReaction(event.eventId, emoji);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                onPressed: () {
                  // Do nothing, let gesture detectors handle it
                },
              ),
              CupertinoContextMenuAction(
                child: const Text('Copy'),
                onPressed: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: event.body));
                },
              ),
              if (event.type == EventTypes.Message && isMe)
                CupertinoContextMenuAction(
                  child: const Text('Edit'),
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                ),
              if (isMe)
                CupertinoContextMenuAction(
                  isDestructiveAction: true,
                  child: const Text('Delete'),
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
            ],
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  // Max width constraint for bubbles
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(
                        isMe ? 20 : (showTail ? 4 : 20),
                      ),
                      bottomRight: Radius.circular(
                        isMe ? (showTail ? 4 : 20) : 20,
                      ),
                    ),
                  ),
                  clipBehavior:
                      Clip.antiAlias, // Clip children (images) to round corners
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Removed Padding wrapper to allow full-width images
                        // 1. Reply Content (If any)
                        if (_getReplyEventId() != null)
                          _buildReplyContext(context, palette, textColor),

                        // 2. Main Content
                        _buildContent(context, textColor),
                      ],
                    ),
                  ),
                ),
                // Reactions
                // Using manual extraction to avoid SDK version mismatches
                Builder(
                  builder: (context) {
                    final reactionData = _getReactions();
                    if (reactionData.isNotEmpty) {
                      return _buildReactions(context, palette, reactionData);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Manually extract reaction counts from event.unsigned
  Map<String, int> _getReactions() {
    try {
      final unsigned = event.unsigned;
      if (unsigned == null) return {};

      final relations = unsigned['m.relations'];
      if (relations is! Map) return {};

      final annotations = relations['m.annotation'];
      if (annotations is! Map) return {};

      final chunk = annotations['chunk'];
      if (chunk is! List) return {};

      final counts = <String, int>{};
      for (final item in chunk) {
        if (item is Map) {
          final key = item['key'];
          if (key is String) {
            counts[key] = (counts[key] ?? 0) + 1;
          }
        }
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  void _showReactionPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => ReactionPickerSheet(
        onEmojiSelected: (emoji) {
          Navigator.pop(context);
          event.room.sendReaction(event.eventId, emoji);
        },
      ),
    );
  }

  Widget _buildReactions(
    BuildContext context,
    dynamic palette,
    Map<String, int> reactions,
  ) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: reactions.entries.map((entry) {
          final key = entry.key; // The emoji
          final count = entry.value;

          return GestureDetector(
            onTap: () {
              // Toggle reaction
              event.room.sendReaction(event.eventId, key);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: palette.inputBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(key, style: const TextStyle(fontSize: 14)),
                  if (count > 1) ...[
                    const Gap(4),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.secondaryText,
                        fontWeight: FontWeight.bold,
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

  String? _getReplyEventId() {
    // 1. Try SDK getter
    // if (event.relationshipEventId != null) return event.relationshipEventId; // Sometimes null

    // 2. Fallback: Parse content manually
    final content = event.content;
    final relatesTo = content['m.relates_to'];
    if (relatesTo is Map) {
      if (relatesTo['m.in_reply_to'] is Map) {
        return relatesTo['m.in_reply_to']['event_id'];
      }
    }
    return null;
  }

  String _getCleanBody() {
    // 1. Handle Edit
    final content = event.content['m.new_content'] ?? event.content;
    var body = '';
    if (content is Map) {
      body = content['body']?.toString() ?? '';
    }

    // 2. Strip Reply Fallback
    // Only strip if it actually looks like a reply fallback (starts with >)
    // and we have a relationship event (reply).
    if (_getReplyEventId() != null) {
      final lines = body.split('\n');
      var i = 0;
      // Skip lines starting with '>'
      while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
        i++;
      }
      // Skip empty lines after the quote
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      if (i > 0 && i < lines.length) {
        body = lines.sublist(i).join('\n');
      }
    }
    return body.trim();
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    if (event.redactedBecause != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'Message deleted',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.6),
            fontSize: 16,
            fontStyle: FontStyle.italic,
            height: 1.3,
          ),
        ),
      );
    }

    if (event.type == EventTypes.Encrypted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.lock_fill, size: 14, color: textColor),
            const Gap(6),
            Text(
              'Encrypted message',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (event.messageType == MessageTypes.Image ||
        event.type == EventTypes.Sticker) {
      return _buildImage(context);
    } else if (event.messageType == MessageTypes.Video) {
      return VideoBubble(
        event: event,
        isMe: isMe,
        client: client,
      ); // Assuming this file exists
    } else if (event.messageType == MessageTypes.File ||
        event.messageType == MessageTypes.Audio) {
      return Padding(
        padding: const EdgeInsets.all(5),
        child: FileBubble(event: event, isMe: isMe),
      );
    } else if (event.messageType == MessageTypes.Location) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.location_solid, size: 16),
            const SizedBox(width: 8),
            Text(
              'Shared Location',
              style: TextStyle(
                color: textColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      );
    }

    // Text Message
    final displayBody = _getCleanBody();
    final isEdited = event.content['m.new_content'] != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            height: 1.3,
            fontFamily: DefaultTextStyle.of(context).style.fontFamily,
          ),
          children: [
            TextSpan(text: displayBody),
            if (isEdited)
              TextSpan(
                text: ' (edited)',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    // Logic to prevent layout shifts
    final maxSize = event.messageType == MessageTypes.Sticker ? 128.0 : 300.0;

    // Extract dimensions from event content
    final info = event.content['info'];
    int? w;
    int? h;
    String? blurhash;

    if (info is Map) {
      w = info['w'] as int?;
      h = info['h'] as int?;
      blurhash = info['xyz.amorgan.blurhash'] as String?;
    }
    // Fallback if not in info
    blurhash ??= event.content['xyz.amorgan.blurhash'] as String?;

    // Default dimensions
    double? width = maxSize;
    double? height = maxSize;
    BoxFit fit = event.messageType == MessageTypes.Sticker
        ? BoxFit.contain
        : BoxFit.cover;

    // Calculate aspect ratio if available
    if (w != null && h != null && w > 0 && h > 0) {
      fit = BoxFit.contain;

      // Calculate dimensions preserving aspect ratio within maxSize bounding box
      final ratio = w / h;
      if (ratio > 1) {
        // Landscape
        width = maxSize;
        height = maxSize / ratio;
      } else {
        // Portrait or Square
        height = maxSize;
        width = maxSize * ratio;
      }

      // Ensure minimum size
      if (height < 32) height = 32;
      if (width < 32) width = 32;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => FullScreenImageViewer(
              images: [event], // TODO: Pass timeline images
              initialIndex: 0,
              client: client,
            ),
          ),
        );
      },
      child: MxcImage(
        event: event,
        fit: fit,
        width: width,
        height: height,
        borderRadius: BorderRadius.zero,
        isThumbnail: true,
        placeholder: (_) => BlurHash(
          blurhash: blurhash,
          width: width ?? maxSize,
          height: height ?? maxSize,
          fit: fit,
        ),
      ),
    );
  }

  Widget _buildReplyContext(
    BuildContext context,
    dynamic palette,
    Color textColor,
  ) {
    final replyEventId = _getReplyEventId();
    if (replyEventId == null) return const SizedBox.shrink();

    // Try to find event in timeline
    final existingEvent = timeline?.events.cast<Event?>().firstWhere(
      (e) => e?.eventId == replyEventId,
      orElse: () => null,
    );

    // If we have a dummy, try to fetch the real event if not found
    // (Skipping network fetch for now as requestEvent is not available)
    final future = Future.value(existingEvent);

    return FutureBuilder<Event?>(
      future: future,
      builder: (context, snapshot) {
        final replyEvent = snapshot.data ?? existingEvent;

        // If still null or loading, show placeholder
        if (replyEvent == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: textColor.withValues(alpha: 0.5),
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.reply,
                    size: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                  const Gap(8),
                  Text(
                    'Reply...',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final displayName = replyEvent.senderFromMemoryOrFallback
            .calcDisplayname();
        var body = replyEvent.body;

        // Strip fallback quotes
        final lines = body.split('\n');
        var i = 0;
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          i++;
        }
        while (i < lines.length && lines[i].trim().isEmpty) {
          i++;
        }
        if (i > 0 && i < lines.length) {
          body = lines.sublist(i).join('\n');
        }

        IconData? icon;
        // Check message type for icon and localized text
        if (replyEvent.messageType == MessageTypes.Image) {
          body = 'Photo';
          icon = CupertinoIcons.photo;
        } else if (replyEvent.messageType == MessageTypes.Video) {
          body = 'Video';
          icon = CupertinoIcons.video_camera;
        } else if (replyEvent.messageType == MessageTypes.File) {
          body = 'File';
          icon = CupertinoIcons.doc;
        } else if (replyEvent.messageType == MessageTypes.Audio) {
          body = 'Audio';
          icon = CupertinoIcons.mic;
        } else if (replyEvent.messageType == MessageTypes.Sticker) {
          body = 'Sticker';
          icon = CupertinoIcons.smiley;
        } else if (replyEvent.messageType == MessageTypes.Location) {
          body = 'Location';
          icon = CupertinoIcons.location_solid;
        }

        final content = replyEvent.content;
        final urlString =
            content['url'] as String? ??
            (content['file'] is Map
                ? (content['file'] as Map)['url'] as String?
                : null);
        final attachmentUri = (urlString?.isNotEmpty ?? false)
            ? Uri.tryParse(urlString!)
            : null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: GestureDetector(
            onTap: () => onReplyTap(replyEventId),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: textColor.withValues(alpha: 0.5),
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (attachmentUri != null &&
                      replyEvent.messageType == MessageTypes.Image)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: MxcImage(
                        uri: replyEvent.type == EventTypes.Encrypted
                            ? null
                            : attachmentUri,
                        event: replyEvent,
                        client: client,
                        fit: BoxFit.cover,
                        isThumbnail: true,
                        width: 44,
                        height: 44,
                        borderRadius: BorderRadius.circular(4),
                        placeholder: (_) => Container(color: Colors.white10),
                      ),
                    ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Icon(
                                  icon,
                                  size: 14,
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                                const Gap(4),
                              ],
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  body,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
