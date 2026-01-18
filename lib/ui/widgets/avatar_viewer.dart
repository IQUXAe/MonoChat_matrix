import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';

/// Full screen avatar viewer
class AvatarViewer extends StatelessWidget {
  final Uri uri;
  final Client client;
  final String displayName;

  const AvatarViewer({
    super.key,
    required this.uri,
    required this.client,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
        border: null,
        middle: Text(
          displayName,
          style: const TextStyle(color: CupertinoColors.white),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white),
        ),
      ),
      child: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: MxcImage(
            uri: uri,
            client: client,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            fit: BoxFit.contain,
            isThumbnail: false,
          ),
        ),
      ),
    );
  }
}
