import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:logging/logging.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

import '../domain/repositories/chat_repository.dart';
import '../utils/image_compressor.dart';

// Top-level function for compute
Future<Uint8List> _readBytes(String path) async {
  return File(path).readAsBytes();
}

// Compress image in isolate
Future<CompressedImage?> _compressImageIsolate(Uint8List bytes) async {
  return compressImage(bytes, maxDimension: 1600, quality: 85);
}

/// Controller for individual chat screens.
///
/// Handles message sending, file attachments, typing indicators,
/// and read receipts. Uses [ChatRepository] for actual Matrix operations.
class ChatController extends ChangeNotifier {
  final Room room;
  final ChatRepository _chatRepository;
  static final Logger _log = Logger('ChatController');

  Client get client => room.client;

  Event? _replyingTo;
  Event? get replyingTo => _replyingTo;

  String? _lastReadEventId;
  DateTime? _lastTypingTime;
  Timer? _typingTimer;
  StreamSubscription? _syncSubscription;

  bool _isDragging = false;
  bool get isDragging => _isDragging;

  final List<String> _processingFiles = [];
  List<String> get processingFiles => List.unmodifiable(_processingFiles);

  final List<XFile> _attachmentDrafts = [];
  List<XFile> get attachmentDrafts => List.unmodifiable(_attachmentDrafts);

  ChatController({required this.room, required ChatRepository chatRepository})
    : _chatRepository = chatRepository {
    _init();
  }

  void _init() {
    markAsRead();

    // Listen to sync to update read markers
    _syncSubscription = client.onSync.stream.listen((_) {
      markAsRead();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  void setDragging(bool dragging) {
    if (_isDragging != dragging) {
      _isDragging = dragging;
      notifyListeners();
    }
  }

  void _addToProcessing(String name) {
    _processingFiles.add(name);
    notifyListeners();
  }

  void _removeFromProcessing(String name) {
    _processingFiles.remove(name);
    notifyListeners();
  }

  // --- Draft Handling ---

  void addAttachment(XFile file) {
    _attachmentDrafts.add(file);
    notifyListeners();
  }

  void removeAttachment(XFile file) {
    _attachmentDrafts.remove(file);
    notifyListeners();
  }

  void clearAttachments() {
    _attachmentDrafts.clear();
    notifyListeners();
  }

  // --- Drop Handling ---

  Future<void> handleDrop(List<XFile> files) async {
    setDragging(false);

    for (final file in files) {
      if (await _isDirectory(file.path)) {
        _log.fine('Skipping directory: ${file.path}');
        continue;
      }
      addAttachment(file);
    }
  }

  Future<bool> _isDirectory(String path) async {
    return FileSystemEntity.isDirectory(path);
  }

  void setReplyTo(Event? event) {
    _replyingTo = event;
    notifyListeners();
  }

  // --- Sending ---

  /// Send a text message, optionally with draft attachments
  Future<void> sendMessage(String text) async {
    final hasAttachments = _attachmentDrafts.isNotEmpty;
    if (text.trim().isEmpty && !hasAttachments) return;

    final replyTo = _replyingTo;
    final attachmentsToSend = List<XFile>.from(_attachmentDrafts);

    // Clear UI state immediately
    _replyingTo = null;
    _attachmentDrafts.clear();
    notifyListeners();

    // Send files with default compression
    if (attachmentsToSend.isNotEmpty) {
      await sendFiles(attachmentsToSend, compress: true, replyTo: replyTo);
    }

    // Send text after files
    if (text.trim().isNotEmpty) {
      await _chatRepository.sendTextMessage(
        room: room,
        text: text,
        inReplyTo: attachmentsToSend.isEmpty ? replyTo : null,
      );
    }
  }

  /// Send files with optional compression
  ///
  /// This is called by the SendFileDialog or directly for quick sends.
  /// [compress] - if true, images will be resized to max 1600px
  /// [replyTo] - optional event to reply to
  Future<void> sendFiles(
    List<XFile> files, {
    bool compress = true,
    Event? replyTo,
  }) async {
    final List<({Uri uri, String name, String? mime, int size})>
    uploadedAssets = [];

    // 1. Upload Phase
    for (final file in files) {
      _addToProcessing(file.name);
      try {
        final mime = lookupMimeType(file.path);
        var uploadMime = mime;
        Uint8List? uploadBytes;
        String? uploadPath = file.path;
        int uploadSize = 0;

        // Compress images before upload (except GIFs) if enabled
        if (compress &&
            mime != null &&
            mime.startsWith('image/') &&
            !mime.contains('gif')) {
          // Only read bytes if we intend to compress
          final originalBytes = await compute(_readBytes, file.path);
          if (originalBytes.length > 20000) {
            _log.fine('Compressing image: ${file.name}');
            final compressed = await _compressImageIsolate(originalBytes);
            if (compressed != null) {
              uploadBytes = compressed.bytes;
              uploadMime = compressed.mimeType;
              uploadSize = compressed.bytes.length;
              _log.fine('Compressed: ${file.name} to $uploadSize bytes');
              uploadPath = null; // Use bytes, not path
            }
          }
        }

        // If uploadSize is still 0 (no compression or failed), estimate from file
        if (uploadSize == 0) {
          uploadSize = await File(file.path).length();
        }

        // Upload via repository
        // Pass path if we didn't compress, pass bytes if we did
        final result = await _chatRepository.uploadContent(
          bytes: uploadBytes,
          filename: file.name,
          contentType: uploadMime,
          filePath: uploadPath,
        );

        result.fold(
          (uri) {
            uploadedAssets.add((
              uri: uri,
              name: file.name,
              mime: uploadMime,
              size: uploadSize,
            ));
          },
          (exception) {
            _log.severe(
              'Failed to upload file attachment: ${file.name}',
              exception,
            );
          },
        );
      } catch (e, s) {
        _log.severe('Failed to upload file attachment: ${file.name}', e, s);
      } finally {
        _removeFromProcessing(file.name);
      }
    }

    // 2. Send file events
    Event? replyEventUsed = replyTo;

    for (final asset in uploadedAssets) {
      // Determine MsgType based on mime
      String msgType = MessageTypes.File;
      if (asset.mime != null) {
        if (asset.mime!.startsWith('image/')) {
          msgType = MessageTypes.Image;
        } else if (asset.mime!.startsWith('video/')) {
          msgType = MessageTypes.Video;
        } else if (asset.mime!.startsWith('audio/')) {
          msgType = MessageTypes.Audio;
        }
      }

      final result = await _chatRepository.sendFileMessage(
        room: room,
        mxcUri: asset.uri,
        filename: asset.name,
        msgType: msgType,
        size: asset.size,
        mimeType: asset.mime,
        inReplyTo: replyEventUsed,
      );

      result.fold(
        (_) => replyEventUsed = null, // Only first file is a reply
        (e) => _log.severe('Failed to send file message', e),
      );
    }
  }

  // Stubs for picker callbacks to just add to draft
  void attachFile(XFile file) => addAttachment(file);

  void attachFileFromPlatform(PlatformFile file) {
    if (file.path != null) {
      addAttachment(XFile(file.path!, name: file.name));
    }
  }

  void updateTyping(bool isTyping) {
    final now = DateTime.now();
    if (_lastTypingTime != null &&
        now.difference(_lastTypingTime!) < const Duration(milliseconds: 1000) &&
        isTyping) {
      return;
    }

    _lastTypingTime = now;
    _chatRepository.setTyping(room, isTyping);
  }

  void markAsRead() async {
    if (room.membership != Membership.join) return;

    final lastEventId = room.lastEvent?.eventId;
    if (lastEventId == null ||
        lastEventId.startsWith('m-') || // Local echo or special
        lastEventId.startsWith('MonoChat') ||
        lastEventId == _lastReadEventId) {
      return;
    }

    _lastReadEventId = lastEventId;

    final result = await _chatRepository.markAsRead(room, lastEventId);
    result.fold(
      (_) {}, // Success - nothing to do
      (e) => _log.warning('Failed to set read marker', e),
    );
  }
}
