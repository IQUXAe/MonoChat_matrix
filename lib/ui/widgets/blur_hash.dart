import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:blurhash_dart/blurhash_dart.dart' as b;
import 'package:image/image.dart' as image;

class BlurHash extends StatefulWidget {
  final double width;
  final double height;
  final String blurhash;
  final BoxFit fit;

  const BlurHash({
    super.key,
    String? blurhash,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  }) : blurhash = blurhash ?? 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

  @override
  State<BlurHash> createState() => _BlurHashState();
}

class _BlurHashState extends State<BlurHash> {
  Uint8List? _data;

  static Future<Uint8List> getBlurhashData(BlurhashData blurhashData) async {
    final blurhash = b.BlurHash.decode(blurhashData.hsh);
    final img = blurhash.toImage(blurhashData.w, blurhashData.h);
    return Uint8List.fromList(image.encodePng(img));
  }

  Future<Uint8List?> _computeBlurhashData() async {
    if (_data != null) return _data!;

    if (widget.width <= 0 || widget.height <= 0) return null;

    final ratio = widget.width / widget.height;
    var width = 32;
    var height = 32;
    if (ratio > 1.0) {
      height = (width / ratio).round();
    } else {
      width = (height * ratio).round();
    }

    if (width <= 0) width = 1;
    if (height <= 0) height = 1;

    try {
      return _data ??= await compute(
        getBlurhashData,
        BlurhashData(hsh: widget.blurhash, w: width, h: height),
      );
    } catch (e) {
      debugPrint('Blurhash computation failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _computeBlurhashData(),
      initialData: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: CupertinoColors.systemGrey5,
          );
        }
        return Image.memory(
          data,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class BlurhashData {
  final String hsh;
  final int w;
  final int h;

  const BlurhashData({required this.hsh, required this.w, required this.h});
}
