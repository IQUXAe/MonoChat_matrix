import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/services/cache/secure_cache_service.dart';
import 'package:monochat/utils/client_download_content_extension.dart';
import 'package:monochat/utils/matrix_file_extension.dart';

class MxcImage extends StatefulWidget {
  final Uri? uri;
  final Event? event;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool isThumbnail;
  final bool animated;
  final Duration retryDuration;
  final Duration animationDuration;
  final Curve animationCurve;
  final ThumbnailMethod thumbnailMethod;
  final Widget Function(BuildContext context)? placeholder;
  final String? cacheKey;
  final String? cacheCategory;
  final Client? client;
  final BorderRadius borderRadius;
  final bool preloadImage;

  const MxcImage({
    super.key,
    this.uri,
    this.event,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.isThumbnail = true,
    this.animated = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.retryDuration = const Duration(seconds: 2),
    this.animationCurve = Curves.easeOut,
    this.thumbnailMethod = ThumbnailMethod.scale,
    this.cacheKey,
    this.cacheCategory,
    this.client,
    this.borderRadius = BorderRadius.zero,
    this.preloadImage = false,
  });

  @override
  State<MxcImage> createState() => _MxcImageState();
}

class _MxcImageState extends State<MxcImage> {
  static final Map<String, Future<Uint8List?>> _loadingCache = {};
  Uint8List? _imageDataNoCache;
  bool _isLoading = false;

  String? get _globalCacheKey {
    if (widget.uri != null) {
      return '${widget.uri}_${widget.width}_${widget.height}_${widget.isThumbnail}';
    }
    if (widget.event != null) {
      return '${widget.event!.eventId}_${widget.isThumbnail}';
    }
    return null;
  }

  Uint8List? get _imageData => _imageDataNoCache;

  Future<Uint8List?> _load() async {
    if (!mounted) return null;

    // 1. Handle Local Files
    if (widget.uri != null && widget.uri!.isScheme('file')) {
      final file = File(widget.uri!.toFilePath());
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    }

    final client = widget.client ?? widget.event?.room.client;
    if (client == null) return null;

    final uri = widget.uri;
    final event = widget.event;

    if (uri != null) {
      if (!uri.hasAbsolutePath || uri.host.isEmpty) {
        return null;
      }

      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final width = widget.width;
      final realWidth = width == null ? null : width * devicePixelRatio;
      final height = widget.height;
      final realHeight = height == null ? null : height * devicePixelRatio;

      final remoteData = await client.downloadMxcCached(
        uri,
        width: realWidth,
        height: realHeight,
        thumbnailMethod: widget.thumbnailMethod,
        isThumbnail: widget.isThumbnail,
        animated: widget.animated,
      );
      return remoteData;
    }

    if (event != null) {
      final data = await event.downloadAndDecryptAttachment(
        getThumbnail: widget.isThumbnail,
      );
      if (data.detectFileType is MatrixImageFile ||
          widget.isThumbnail ||
          event.messageType == MessageTypes.Image) {
        return data.bytes;
      }
    }
    return null;
  }

  Future<void> _tryLoad() async {
    if (_imageData != null || _isLoading || !mounted) {
      return;
    }

    final cacheKey = _globalCacheKey ?? widget.cacheKey;

    // 1. Check Secure Cache (L1/L2)
    if (cacheKey != null) {
      final cachedData = await SecureCacheService().get(cacheKey);
      if (cachedData != null && mounted) {
        setState(() {
          _imageDataNoCache = cachedData;
        });
        return;
      }
    }

    if (cacheKey != null && _loadingCache.containsKey(cacheKey)) {
      // Wait for existing load operation
      final data = await _loadingCache[cacheKey];
      if (mounted && data != null) {
        setState(() {
          _imageDataNoCache = data;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final loadFuture = _load();
      if (cacheKey != null) {
        _loadingCache[cacheKey] = loadFuture;
      }

      final data = await loadFuture;

      if (cacheKey != null) {
        _loadingCache.remove(cacheKey);
      }

      if (!mounted) return;

      if (data != null) {
        // Save to Secure Cache
        if (cacheKey != null) {
          final category =
              widget.cacheCategory ?? (widget.isThumbnail ? 'image' : null);
          await SecureCacheService().put(cacheKey, data, category: category);
        }
      }

      setState(() {
        _isLoading = false;
        if (data != null) {
          _imageDataNoCache = data;
        }
      });
    } catch (e) {
      // Handle errors
      if (cacheKey != null) {
        _loadingCache.remove(cacheKey);
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      // Simple retry logic could live here
      if (mounted) {
        // Check mounted before waiting? No, wait then check.
        await Future.delayed(widget.retryDuration);
      }
      if (mounted) {
        _tryLoad();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.preloadImage) {
      // ignore: discard_returned_futures
      _tryLoad();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryLoad();
      });
    }
  }

  @override
  void didUpdateWidget(MxcImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri ||
        oldWidget.event?.eventId != widget.event?.eventId) {
      // Data changed, reload
      _imageDataNoCache = null; // Clear local cache
      _tryLoad();
    }
  }

  Widget placeholder(BuildContext context) =>
      widget.placeholder?.call(context) ??
      Container(
        width: widget.width,
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: widget.borderRadius,
        ),
        child: _isLoading
            ? const CupertinoActivityIndicator(radius: 8) // IOS style spinner
            : Icon(
                CupertinoIcons.photo,
                size: min(widget.height ?? 64, 64),
                color: CupertinoColors.systemGrey,
              ),
      );

  @override
  Widget build(BuildContext context) {
    final data = _imageData;
    final hasData = data != null && data.isNotEmpty;

    if (hasData) {
      return AnimatedSwitcher(
        duration: widget.animationDuration,
        child: ClipRRect(
          key: ValueKey(data.hashCode), // Important for AnimatedSwitcher
          borderRadius: widget.borderRadius,
          child: Image.memory(
            data,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            cacheWidth: widget.width != null && widget.width! < double.infinity
                ? (widget.width! * MediaQuery.devicePixelRatioOf(context))
                      .round()
                : null,
            cacheHeight:
                widget.height != null && widget.height! < double.infinity
                ? (widget.height! * MediaQuery.devicePixelRatioOf(context))
                      .round()
                : null,
            filterQuality: widget.isThumbnail
                ? FilterQuality.low
                : FilterQuality.medium,
            errorBuilder: (context, e, s) {
              return SizedBox(
                width: widget.width,
                height: widget.height,
                child: Container(
                  color: CupertinoColors.systemGrey5,
                  child: Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: min(widget.height ?? 64, 64),
                    color: CupertinoColors.systemRed,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return placeholder(context);
  }
}
