import 'dart:typed_data';

import 'package:matrix/matrix.dart' hide Result;

import '../../core/result.dart';

/// Abstract repository for chat operations.
///
/// Handles message sending, file uploads, typing indicators,
/// and read receipts.
abstract class ChatRepository {
  /// Uploads file content to the Matrix server.
  ///
  /// Returns [Success] with the MXC URI of the uploaded file,
  /// or [Failure] with a [FileUploadFailedException] if upload fails.
  Future<Result<Uri>> uploadContent({
    Uint8List? bytes,
    required String filename,
    String? contentType,
    String? filePath,
  });

  /// Sends a text message to the specified room.
  ///
  /// Returns [Success] with the event ID of the sent message,
  /// or [Failure] with a [MessageSendFailedException] if sending fails.
  Future<Result<String>> sendTextMessage({
    required Room room,
    required String text,
    Event? inReplyTo,
  });

  /// Sends a file message to the specified room.
  ///
  /// The file should already be uploaded via [uploadContent].
  ///
  /// [msgType] should be one of [MessageTypes.File], [MessageTypes.Image],
  /// or [MessageTypes.Video].
  Future<Result<String>> sendFileMessage({
    required Room room,
    required Uri mxcUri,
    required String filename,
    required String msgType,
    required int size,
    String? mimeType,
    Event? inReplyTo,
  });

  /// Sets the typing indicator for the current user in a room.
  ///
  /// This is fire-and-forget; errors are logged but not thrown.
  Future<void> setTyping(Room room, bool isTyping);

  /// Marks the room as read up to the specified event.
  ///
  /// Also clears the unread notification flag.
  Future<Result<void>> markAsRead(Room room, String eventId);
}
