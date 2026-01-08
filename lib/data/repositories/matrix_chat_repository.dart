import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart' hide Result;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/exceptions/app_exception.dart';
import '../../core/exceptions/exception_mapper.dart';
import '../../core/result.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../services/matrix_service.dart';
import '../../services/background_uploader.dart';

/// Matrix SDK implementation of [ChatRepository].
class MatrixChatRepository implements ChatRepository {
  final MatrixService _service;
  static final Logger _log = Logger('MatrixChatRepository');

  MatrixChatRepository(this._service);

  Client? get _client => _service.client;

  @override
  Future<Result<Uri>> uploadContent({
    Uint8List? bytes,
    required String filename,
    String? contentType,
    String? filePath,
  }) async {
    try {
      if (_client == null) {
        return const Failure(ClientNotInitializedException());
      }

      String pathForUpload = filePath ?? '';

      // If no path provided (e.g. in-memory bytes), write to temp file
      // to ensure we can use the efficient background uploader
      if (pathForUpload.isEmpty && bytes != null) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            p.join(
              tempDir.path,
              'upload_${DateTime.now().millisecondsSinceEpoch}_$filename',
            ),
          );
          await tempFile.writeAsBytes(bytes);
          pathForUpload = tempFile.path;
        } catch (e) {
          _log.warning('Failed to write temp file for upload', e);
        }
      }

      // Try background upload first for better UI responsiveness
      if (pathForUpload.isNotEmpty) {
        final uploadUri = await _getUploadUri();
        if (uploadUri != null) {
          final result = await _backgroundUpload(
            uploadUri: uploadUri,
            filePath: pathForUpload,
            filename: filename,
            contentType: contentType,
          );
          if (result != null) {
            return Success(result);
          }
        }
      }

      // Fallback: main thread upload
      Uint8List? bytesToUpload = bytes;
      if (bytesToUpload == null && pathForUpload.isNotEmpty) {
        try {
          bytesToUpload = await File(pathForUpload).readAsBytes();
        } catch (e) {
          _log.warning('Failed to read file for fallback upload', e);
        }
      }

      if (bytesToUpload == null) {
        return Failure(
          FileUploadFailedException(
            filename: filename,
            debugInfo: 'No bytes enabled for fallback',
          ),
        );
      }

      final uri = await _client!.uploadContent(
        bytesToUpload,
        filename: filename,
        contentType: contentType,
      );
      return Success(uri);
    } catch (e, s) {
      _log.warning('Failed to upload content: $filename', e, s);
      return Failure(
        FileUploadFailedException(filename: filename, debugInfo: e.toString()),
      );
    }
  }

  /// Get the media upload URL from homeserver
  Future<String?> _getUploadUri() async {
    try {
      final homeserver = _client?.homeserver;
      if (homeserver == null) return null;

      // Matrix spec: /_matrix/media/v3/upload
      return '${homeserver.toString().replaceAll(RegExp(r'/$'), '')}/_matrix/media/v3/upload';
    } catch (e) {
      _log.fine('Could not get upload URI', e);
      return null;
    }
  }

  /// Upload using background isolate
  Future<Uri?> _backgroundUpload({
    required String uploadUri,
    required String filePath,
    required String filename,
    String? contentType,
  }) async {
    try {
      // Ensure uploader is initialized
      await backgroundUploader.init();

      final headers = <String, String>{};
      if (_client?.accessToken != null) {
        headers['Authorization'] = 'Bearer ${_client!.accessToken}';
      }

      final response = await backgroundUploader.uploadAndWait(
        uploadUrl: '$uploadUri?filename=${Uri.encodeComponent(filename)}',
        filePath: filePath,
        filename: filename,
        contentType: contentType,
        headers: headers,
      );

      if (response.isSuccess && response.mxcUri != null) {
        _log.fine('Background upload successful: ${response.mxcUri}');
        return Uri.parse(response.mxcUri!);
      } else {
        _log.warning('Background upload failed: ${response.error}');
        return null;
      }
    } catch (e) {
      _log.warning('Background upload exception', e);
      return null;
    }
  }

  @override
  Future<Result<String>> sendTextMessage({
    required Room room,
    required String text,
    Event? inReplyTo,
  }) async {
    try {
      final eventId = await room.sendTextEvent(text, inReplyTo: inReplyTo);
      return Success(eventId ?? '');
    } catch (e, s) {
      _log.warning('Failed to send text message', e, s);
      return Failure(MessageSendFailedException(debugInfo: e.toString()));
    }
  }

  @override
  Future<Result<String>> sendFileMessage({
    required Room room,
    required Uri mxcUri,
    required String filename,
    required String msgType,
    required int size,
    String? mimeType,
    Event? inReplyTo,
  }) async {
    try {
      final eventId = await room.sendEvent({
        'msgtype': msgType,
        'body': filename,
        'url': mxcUri.toString(),
        'info': {'mimetype': mimeType, 'size': size},
      }, inReplyTo: inReplyTo);
      return Success(eventId ?? '');
    } catch (e, s) {
      _log.warning('Failed to send file message: $filename', e, s);
      return Failure(MessageSendFailedException(debugInfo: e.toString()));
    }
  }

  @override
  Future<void> setTyping(Room room, bool isTyping) async {
    try {
      await room.setTyping(isTyping);
    } catch (e) {
      _log.fine('Typing indicator failed', e);
      // Silent failure - typing indicators are non-critical
    }
  }

  @override
  Future<Result<void>> markAsRead(Room room, String eventId) async {
    try {
      await room.setReadMarker(eventId);
      await room.markUnread(false);
      return const Success(null);
    } catch (e, s) {
      _log.warning('Failed to set read marker', e, s);
      return Failure(ExceptionMapper.map(e, s));
    }
  }
}
