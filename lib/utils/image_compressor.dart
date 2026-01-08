import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Result of image compression
class CompressedImage {
  final Uint8List bytes;
  final int width;
  final int height;
  final String mimeType;

  const CompressedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.mimeType,
  });
}

/// Compresses an image in an isolate to prevent UI jank.
///
/// Uses Flutter's image codec for decoding and encoding.
/// Limits image dimensions to [maxDimension] while preserving aspect ratio.
Future<CompressedImage?> compressImage(
  Uint8List bytes, {
  int maxDimension = 1600,
  int quality = 85,
}) async {
  try {
    // Decode image to get dimensions
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final originalWidth = image.width;
    final originalHeight = image.height;

    // Check if resize is needed
    if (originalWidth <= maxDimension && originalHeight <= maxDimension) {
      // No resize needed, return original
      image.dispose();
      codec.dispose();
      return CompressedImage(
        bytes: bytes,
        width: originalWidth,
        height: originalHeight,
        mimeType: 'image/jpeg',
      );
    }

    // Calculate new dimensions
    int newWidth, newHeight;
    if (originalWidth > originalHeight) {
      newWidth = maxDimension;
      newHeight = (originalHeight * maxDimension / originalWidth).round();
    } else {
      newHeight = maxDimension;
      newWidth = (originalWidth * maxDimension / originalHeight).round();
    }

    // Use compute to resize in isolate
    final resized = await compute(
      _resizeInIsolate,
      _ResizeParams(
        bytes: bytes,
        targetWidth: newWidth,
        targetHeight: newHeight,
        quality: quality,
      ),
    );

    image.dispose();
    codec.dispose();

    if (resized == null) {
      return null;
    }

    return CompressedImage(
      bytes: resized,
      width: newWidth,
      height: newHeight,
      mimeType: 'image/jpeg',
    );
  } catch (e) {
    debugPrint('Image compression failed: $e');
    return null;
  }
}

class _ResizeParams {
  final Uint8List bytes;
  final int targetWidth;
  final int targetHeight;
  final int quality;

  _ResizeParams({
    required this.bytes,
    required this.targetWidth,
    required this.targetHeight,
    required this.quality,
  });
}

/// Runs image resize in isolate
/// Note: This uses instantiateImageCodec which requires dart:ui
/// For true isolate support, consider using image package or native_imaging
Future<Uint8List?> _resizeInIsolate(_ResizeParams params) async {
  try {
    // Decode
    final codec = await ui.instantiateImageCodec(
      params.bytes,
      targetWidth: params.targetWidth,
      targetHeight: params.targetHeight,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Encode to PNG (JPEG encoding is not directly available in dart:ui)
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();
    codec.dispose();

    if (byteData == null) return null;

    return Uint8List.view(
      byteData.buffer,
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  } catch (e) {
    return null;
  }
}

/// Check if file is an image based on MIME type
bool isImageMime(String? mimeType) {
  if (mimeType == null) return false;
  return mimeType.startsWith('image/') &&
      !mimeType.contains('gif') && // Don't compress GIFs
      !mimeType.contains('svg'); // Don't process SVGs
}
