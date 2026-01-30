import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';

class MessageStatusIndicator extends StatelessWidget {
  final Event event;
  final bool isMe;

  const MessageStatusIndicator({
    super.key,
    required this.event,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();

    // Map status to icon
    // Status can be sending, sent, error, queued
    // We can check event.status

    // Default to sent/synced checkmark
    const icon = CupertinoIcons.checkmark_alt_circle;
    const Color color = CupertinoColors.systemGrey;

    if (event.status.isSending) {
      // Empty circle
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: CupertinoColors.systemGrey, width: 1.5),
        ),
      );
    } else if (event.status.isError) {
      // Red exclamation
      return const Icon(
        CupertinoIcons.exclamationmark_circle_fill,
        size: 14,
        color: CupertinoColors.systemRed,
      );
    }

    // Sent / Synced
    return const Icon(icon, size: 14, color: color);
  }
}
