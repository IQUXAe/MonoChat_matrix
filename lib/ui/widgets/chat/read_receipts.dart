import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';

class ReadReceipts extends StatelessWidget {
  final Event event;
  final Client client;

  const ReadReceipts({super.key, required this.event, required this.client});

  @override
  Widget build(BuildContext context) {
    // Helper to safely extract user ID from Receipt object
    String? getUserId(dynamic r) {
      if (r == null) return null;
      try {
        return r.userId;
      } catch (_) {}
      try {
        return r.senderId;
      } catch (_) {}
      try {
        return r.uId;
      } catch (_) {}
      try {
        return r.user?.id;
      } catch (_) {}
      // Try map access if it's a map disguised or toJson
      try {
        final json = r.toJson();
        if (json is Map) {
          return json['userId'] ?? json['senderId'] ?? json['user_id'];
        }
      } catch (_) {}
      return null;
    }

    // Get distinct receipts, excluding ourselves
    final receipts = event.receipts
        .map(getUserId)
        .where((id) => id != null && id != client.userID)
        .cast<String>()
        .toSet()
        .toList();

    if (receipts.isEmpty) return const SizedBox.shrink();

    // Show max 5, overlap them
    final usersToShow = receipts.take(5).toList();

    return SizedBox(
      height: 16,
      width: (usersToShow.length * 12.0) + 14.0, // Estimate width
      child: Stack(
        // Allow overflow for overlapping
        clipBehavior: Clip.none,
        children: List.generate(usersToShow.length, (index) {
          final userId = usersToShow[index];

          return Positioned(
            right: index * 12.0, // Overlap offset
            child: FutureBuilder<User?>(
              // Use requestUser which is the standard async method to get a user
              future: event.room.requestUser(userId),
              builder: (context, snapshot) {
                final user = snapshot.data;

                return Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    // Border removed as requested
                  ),
                  child: MatrixAvatar(
                    avatarUrl: user?.avatarUrl,
                    name: user?.displayName ?? userId,
                    client: client,
                    size: 14,
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
