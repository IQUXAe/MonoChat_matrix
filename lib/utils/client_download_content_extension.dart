import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

extension ClientDownloadContentExtension on Client {
  Future<Uint8List> downloadMxcCached(
    Uri mxc, {
    num? width,
    num? height,
    bool isThumbnail = false,
    bool? animated,
    ThumbnailMethod? thumbnailMethod,
    bool rounded = false,
  }) async {
    // Validate width and height to prevent NaN/Infinity errors
    if (width != null && (!width.isFinite || width <= 0)) width = 64;
    if (height != null && (!height.isFinite || height <= 0)) height = 64;

    // To stay compatible with previous storeKeys:
    final cacheKey = isThumbnail
        // ignore: deprecated_member_use
        ? mxc.getThumbnail(
            this,
            width: width,
            height: height,
            animated: animated,
            method: thumbnailMethod!,
          )
        : mxc;

    final cachedData = await database.getFile(cacheKey);
    if (cachedData != null) return cachedData;

    final httpUri = isThumbnail
        ? await mxc.getThumbnailUri(
            this,
            width: width,
            height: height,
            animated: animated,
            method: thumbnailMethod,
          )
        : await mxc.getDownloadUri(this);

    if (httpUri.host.isEmpty) {
      Logger(
        'DownloadExtension',
      ).warning('Invalid URI generated (no host): $httpUri for mxc: $mxc');
      throw ArgumentError('Invalid URI: No host specified in $httpUri');
    }

    final headers = <String, String>{};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    http.Response response;
    const maxRetries = 3;
    var retryCount = 0;

    // Using basic Logger since MonoChat uses logging package
    final log = Logger('DownloadExtension');

    while (true) {
      try {
        // Use MonoChat's client.someHttpClient or just generic http?
        // MatrixSDK client usually has httpClient internally but it's not always public or easy to reach if wrapped.
        // QuikxChat uses `httpClient` extension or property.
        // `Client` has `httpClient` if using standard Matrix SDK.
        // Wait, standard Matrix SDK `Client` doesn't expose `httpClient` easily unless extended?
        // It seems QuikxChat might have extended it or it's available.
        // Let's assume generic http.get for now or try to use client's ability.
        // Standard Matrix SDK uses `http.Client`.

        // Actually, we can just use `http.get`.
        response = await http.get(httpUri, headers: headers);
        break; // Success, exit retry loop
      } on http.ClientException catch (e) {
        // Handle transient connection errors (connection closed prematurely, etc.)
        retryCount++;
        if (retryCount >= maxRetries) {
          log.warning(
            'Failed to download content from $httpUri after $maxRetries retries',
            e,
          );
          rethrow;
        }
        log.fine(
          'Retrying download ($retryCount/$maxRetries) for $httpUri: $e',
        );
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      } on SocketException catch (e) {
        // Handle socket/network errors
        retryCount++;
        if (retryCount >= maxRetries) {
          log.warning(
            'Network error downloading from $httpUri after $maxRetries retries',
            e,
          );
          rethrow;
        }
        log.fine(
          'Retrying download ($retryCount/$maxRetries) for $httpUri: $e',
        );
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      } catch (e) {
        log.warning('Failed to download content from $httpUri', e);
        rethrow;
      }
    }

    if (response.statusCode == 401) {
      log.warning('Unauthorized access to $httpUri - token may be expired');
      throw Exception('Unauthorized (401)');
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    var imageData = response.bodyBytes;

    if (rounded) {
      imageData = await _convertToCircularImage(
        imageData,
        min(width ?? 64, height ?? 64).round(),
      );
    }

    await database.storeFile(cacheKey, imageData, 0);

    return imageData;
  }
}

Future<Uint8List> _convertToCircularImage(
  Uint8List imageBytes,
  int size,
) async {
  final codec = await instantiateImageCodec(imageBytes);
  final frame = await codec.getNextFrame();
  final originalImage = frame.image;

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  final paint = Paint();
  final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

  final clipPath = Path()
    ..addOval(
      Rect.fromCircle(center: Offset(size / 2, size / 2), radius: size / 2),
    );

  canvas.clipPath(clipPath);

  canvas.drawImageRect(
    originalImage,
    Rect.fromLTWH(
      0,
      0,
      originalImage.width.toDouble(),
      originalImage.height.toDouble(),
    ),
    rect,
    paint,
  );

  final picture = recorder.endRecording();
  final circularImage = await picture.toImage(size, size);

  final byteData = await circularImage.toByteData(format: ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
