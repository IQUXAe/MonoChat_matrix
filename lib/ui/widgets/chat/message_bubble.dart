import 'package:flutter/cupertino.dart';

import 'package:matrix/matrix.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';
import 'package:monochat/ui/widgets/full_screen_image_viewer.dart';
import 'package:monochat/ui/widgets/chat/video_bubble.dart';
import 'package:monochat/ui/widgets/chat/file_bubble.dart'; // Import FileBubble
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';

class MessageBubble extends StatelessWidget {
  final Event event;
  final bool isMe;
  final bool showTail;
  final Client client;

  const MessageBubble({
    super.key,
    required this.event,
    required this.isMe,
    required this.showTail,
    required this.client,
  });

  BorderRadius _getBorderRadius() {
    return BorderRadius.only(
      topLeft: const Radius.circular(20),

      topRight: const Radius.circular(20),

      bottomLeft: Radius.circular(isMe ? 20 : (showTail ? 5 : 20)),

      bottomRight: Radius.circular(isMe ? (showTail ? 5 : 20) : 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgType = event.messageType;

    final isImage = msgType == MessageTypes.Image;

    if (isImage) {
      return _buildImageBubble(context);
    }

    if (msgType == MessageTypes.Video) {
      return VideoBubble(event: event, isMe: isMe, client: client);
    }

    if (msgType == MessageTypes.File) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: showTail ? 12 : 3),
          child: FileBubble(event: event, isMe: isMe),
        ),
      );
    }

    final isEncrypted = event.type == EventTypes.Encrypted;

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
                padding: const EdgeInsets.only(left: 14, bottom: 4),

                child: Text(
                  event.senderFromMemoryOrFallback.calcDisplayname(),

                  style: const TextStyle(
                    fontSize: 11,

                    color: CupertinoColors.systemGrey,

                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

              decoration: BoxDecoration(
                color: isEncrypted
                    ? CupertinoColors.systemGrey6
                    : (isMe
                          ? CupertinoColors.activeBlue
                          : const Color(
                              0xFFE9E9EB,
                            )), // iOS Light Gray (approx systemGrey5/6 but flatter)

                borderRadius: _getBorderRadius(),
              ),

              child: _buildContent(context),
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

  Widget _buildContent(BuildContext context) {
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

    return Text(
      event.body,

      style: TextStyle(
        color: isMe ? CupertinoColors.white : CupertinoColors.black,

        fontSize: 17,

        height: 1.2,

        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildImageBubble(BuildContext context) {
    // 1. Resolve URI
    String? uriStr = event.content.tryGet<String>('url');
    if (uriStr == null) {
      final Map? file = event.content['file'] as Map?;
      uriStr = file?['url'] as String?;
    }
    if (uriStr == null) return const SizedBox.shrink();
    final uri = Uri.tryParse(uriStr);

    // 2. Resolve Dimensions & Aspect Ratio
    // Matrix events usually have 'info' -> {'w': 100, 'h': 100}
    final Map? info = event.content['info'] as Map?;
    final int? metaW = info?['w'] as int?;
    final int? metaH = info?['h'] as int?;

    double? width;
    double? height;
    double aspectRatio = 1.0;

    if (metaW != null && metaH != null && metaW > 0 && metaH > 0) {
      aspectRatio = metaW / metaH;

      // Calculate constrained size
      final double maxWidth = MediaQuery.of(context).size.width * 0.70;
      final double maxHeight = 400.0; // Max height cap

      if (aspectRatio > 1) {
        // Landscape
        width = (metaW < maxWidth) ? metaW.toDouble() : maxWidth;
        height = width / aspectRatio;
      } else {
        // Portrait
        height = (metaH < maxHeight) ? metaH.toDouble() : maxHeight;
        width = height * aspectRatio;

        if (width > maxWidth) {
          width = maxWidth;
          height = width / aspectRatio;
        }
      }
    } else {
      // Fallback if no metadata
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
              // Wrap in Container with explicit size to prevent jumping
              child: GestureDetector(
                onTap: () async {
                  // Gather all images currently loaded in the timeline for the gallery
                  final timeline = await event.room.getTimeline();
                  final imageEvents = timeline.events
                      .where((e) => e.messageType == MessageTypes.Image)
                      .toList();

                  // Fallback: if somehow current event isn't in timeline (rare), add it or just show it alone
                  if (!imageEvents.any((e) => e.eventId == event.eventId)) {
                    imageEvents.add(event);
                  }

                  if (!context.mounted) return;

                  // Sort by timestamp if needed? Usually timeline is ordered.
                  // But 'timeline' in Matrix SDK is usually newest-first or oldest-first depending on implementation.
                  // We'll trust the order for now.

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
                  color: CupertinoColors.systemGrey5, // Placeholder color
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
}
