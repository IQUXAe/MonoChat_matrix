import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';
import 'package:monochat/ui/widgets/presence_builder.dart';

class MatrixAvatar extends StatelessWidget {
  final Uri? avatarUrl;
  final String? name;
  final double size;
  final Client client;
  final String? userId; // Added for presence
  final double? borderRadius;

  const MatrixAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.client,
    this.userId,
    this.size = 40.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(borderRadius ?? size / 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: _buildImage(context),
    );

    if (userId == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: 0,
          right: 0,
          child: PresenceBuilder(
            client: client,
            userId: userId!,
            builder: (context, presence) {
              final isOnline = presence?.presence == PresenceType.online;
              // Only show if known state?
              // Let's mimic iOS: Green dot for online. Maybe nothing for offline?
              // The user requested "indicators online/offline".

              Color color;
              if (isOnline) {
                color = CupertinoColors.activeGreen;
              } else if (presence?.presence == PresenceType.unavailable) {
                color = CupertinoColors.systemYellow;
              } else {
                // offline or unknown
                return const SizedBox.shrink();
              }

              return Container(
                width: size * 0.3, // 30% of avatar size
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.systemBackground,
                    width: 2,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.5,
          color: CupertinoColors.systemGrey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (avatarUrl == null ||
        avatarUrl.toString().isEmpty ||
        avatarUrl.toString() == 'null') {
      return _buildPlaceholder();
    }

    return MxcImage(
      uri: avatarUrl,
      client: client,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
