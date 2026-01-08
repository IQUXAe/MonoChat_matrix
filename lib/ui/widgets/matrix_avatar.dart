import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';

class MatrixAvatar extends StatelessWidget {
  final Uri? avatarUrl;
  final String? name;
  final double size;
  final Client client;

  const MatrixAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.client,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: _buildImage(context),
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
