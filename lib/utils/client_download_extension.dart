import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

extension ClientDownloadContentExtension on Client {
  Future<Uint8List> downloadMxcCached(
    Uri mxc, {
    num? width,
    num? height,
    bool isThumbnail = false,
    bool? animated,
    ThumbnailMethod? thumbnailMethod,
    // Removed 'rounded' parameter - we rely on Flutter widgets (GPU) for clipping now
  }) async {
    // 1. Check Cache
    final cacheKey = isThumbnail
        // ignore: deprecated_member_use
        ? mxc.getThumbnail(
            this,
            width: width,
            height: height,
            animated: animated,
            method: thumbnailMethod ?? ThumbnailMethod.scale,
          )
        : mxc;

    final cachedData = await database?.getFile(cacheKey);
    if (cachedData != null) return cachedData;

    // 2. Prepare URL
    final httpUri = isThumbnail
        ? await mxc.getThumbnailUri(
            this,
            width: width,
            height: height,
            animated: animated,
            method: thumbnailMethod,
          )
        : await mxc.getDownloadUri(this);

    // 3. Download in ISOLATE (Background Thread)
    Uint8List imageData;
    try {
      imageData = await compute(
        _isolatedDownload,
        _DownloadParams(httpUri.toString(), accessToken),
      );
    } catch (e) {
      if (isThumbnail) {
        // Fallback to full download
        final fullUri = await mxc.getDownloadUri(this);
        imageData = await compute(
          _isolatedDownload,
          _DownloadParams(fullUri.toString(), accessToken),
        );
      } else {
        rethrow;
      }
    }

    // REMOVED: _convertToCircularImage call.
    // This was CPU intensive. Now we just return the raw bytes.
    // The UI widgets (ClipRRect/BoxDecoration) will handle rounding on the GPU.

    // 4. Store in Cache
    await database?.storeFile(
      cacheKey,
      imageData,
      DateTime.now().millisecondsSinceEpoch,
    );

    return imageData;
  }
}

extension ClientDownloadStringExtension on String {
  Future<Uri> getDownloadUri(Client client) async {
    return await Uri.parse(this).getDownloadUri(client);
  }
}

// Simple DTO for passing data to Isolate
class _DownloadParams {
  final String url;
  final String? token;
  _DownloadParams(this.url, this.token);
}

// Top-level function runs in separate Isolate
Future<Uint8List> _isolatedDownload(_DownloadParams params) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  client.idleTimeout = const Duration(seconds: 1);

  try {
    final request = await client.getUrl(Uri.parse(params.url));

    if (params.token != null) {
      request.headers.set('Authorization', 'Bearer ${params.token}');
    }
    request.headers.set('Connection', 'close');

    final response = await request.close();

    if (response.statusCode != 200) {
      await response.drain();
      throw Exception('HTTP ${response.statusCode}');
    }

    final chunks = <Uint8List>[];
    int totalLength = 0;

    await for (final chunk in response) {
      final Uint8List chunkBytes = Uint8List.fromList(chunk);
      chunks.add(chunkBytes);
      totalLength += chunkBytes.length;
    }

    final result = Uint8List(totalLength);
    int offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  } finally {
    client.close();
  }
}
