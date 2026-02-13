import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';

import '../domain/repositories/chat_repository.dart';
import '../services/matrix_service.dart';
import '../utils/image_compressor.dart';

// =============================================================================
// ISOLATE FUNCTIONS
// =============================================================================

/// Reads file bytes in isolate for non-blocking IO.
Future<Uint8List> _readBytes(String path) async {
  return File(path).readAsBytes();
}

/// Compresses image in isolate.
Future<CompressedImage?> _compressImageIsolate(Uint8List bytes) async {
  return compressImage(bytes, maxDimension: 1600, quality: 85);
}

// =============================================================================
// CHAT CONTROLLER
// =============================================================================

/// Controller for individual chat screens.
///
/// Manages all chat-related functionality:
/// - Message composition and sending (text, files, replies)
/// - File attachments with compression
/// - Typing indicators
/// - Read receipts (using Timeline)
/// - Drag-and-drop file handling
///
/// Uses [ChatRepository] for Matrix operations and maintains a [Timeline]
/// instance for proper read marker state management.
class ChatController extends ChangeNotifier {
  // ===========================================================================
  // DEPENDENCIES & CONFIGURATION
  // ===========================================================================

  /// The Matrix room this controller manages.
  final Room room;

  /// Repository for Matrix operations.
  final ChatRepository _chatRepository;

  /// Logger instance.
  static final Logger _log = Logger('ChatController');

  /// Convenience getter for the Matrix client.
  Client get client => room.client;

  // ===========================================================================
  // TIMELINE STATE
  // ===========================================================================

  /// Timeline instance for message history and read markers.
  ///
  /// Using Timeline.setReadMarker() instead of Room.setReadMarker()
  /// ensures immediate local state updates.
  Timeline? timeline;

  /// Future tracking timeline loading.
  Future<void>? loadTimelineFuture;

  // ===========================================================================
  // MESSAGE COMPOSITION STATE
  // ===========================================================================

  /// Event being replied to.
  Event? _replyingTo;
  Event? get replyingTo => _replyingTo;

  /// Files queued for sending.
  final List<XFile> _attachmentDrafts = [];
  List<XFile> get attachmentDrafts => List.unmodifiable(_attachmentDrafts);

  /// Files currently being uploaded.
  final List<String> _processingFiles = [];
  List<String> get processingFiles => List.unmodifiable(_processingFiles);

  // ===========================================================================
  // UI STATE
  // ===========================================================================

  /// Whether files are being dragged over the chat.
  bool _isDragging = false;
  bool get isDragging => _isDragging;

  /// Whether user has scrolled up from the bottom.
  bool _scrolledUp = false;

  // ===========================================================================
  // INTERNAL STATE
  // ===========================================================================

  DateTime? _lastTypingTime;
  Timer? _typingTimer;
  StreamSubscription<SyncUpdate>? _syncSubscription;
  Future<void>? _setReadMarkerFuture;
  final StreamController<String> _errorController =
      StreamController.broadcast();
  Stream<String> get onError => _errorController.stream;

  // ===========================================================================
  // SELECTION STATE
  // ===========================================================================

  final Set<String> _selectedEventIds = {};
  bool get isSelectionMode => _selectedEventIds.isNotEmpty;
  Set<String> get selectedEventIds => Set.unmodifiable(_selectedEventIds);

  void toggleSelection(String eventId) {
    if (_selectedEventIds.contains(eventId)) {
      _selectedEventIds.remove(eventId);
    } else {
      _selectedEventIds.add(eventId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedEventIds.clear();
    notifyListeners();
  }

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  /// Creates a chat controller for the given room.
  ChatController({required this.room, required ChatRepository chatRepository})
    : _chatRepository = chatRepository {
    _initialize();
  }

  void _initialize() {
    loadTimelineFuture = _loadTimeline();

    _syncSubscription = client.onSync.stream.listen((_) {
      setReadMarker();
      notifyListeners();
    });
  }

  Future<void> _loadTimeline() async {
    try {
      timeline = await room.getTimeline(onUpdate: _onTimelineUpdate);

      // Clear manual unread flag when entering room
      if (room.markedUnread) {
        room.markUnread(false);
      }

      setReadMarker();
      notifyListeners();
    } catch (e, s) {
      _log.warning('Failed to load timeline', e, s);
      _errorController.add('Failed to load chat history: $e');
    }
  }

  void _onTimelineUpdate() {
    if (!_scrolledUp) {
      setReadMarker();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    timeline?.cancelSubscriptions();
    timeline = null;
    _syncSubscription?.cancel();
    _typingTimer?.cancel();
    _errorController.close();
    super.dispose();
  }

  // ===========================================================================
  // DRAG & DROP
  // ===========================================================================

  /// Updates drag state for visual feedback.
  void setDragging(bool dragging) {
    if (_isDragging != dragging) {
      _isDragging = dragging;
      notifyListeners();
    }
  }

  /// Handles dropped files, filtering out directories.
  Future<void> handleDrop(List<XFile> files) async {
    setDragging(false);

    // Batch add files to avoid notification storm
    var added = false;
    for (final file in files) {
      if (await FileSystemEntity.isDirectory(file.path)) {
        _log.fine('Skipping directory: ${file.path}');
        continue;
      }
      _attachmentDrafts.add(file);
      added = true;
    }

    // Single notification after all files are added
    if (added) {
      notifyListeners();
    }
  }

  // ===========================================================================
  // ATTACHMENTS
  // ===========================================================================

  /// Adds a file to the attachment queue.
  void addAttachment(XFile file) {
    _attachmentDrafts.add(file);
    notifyListeners();
  }

  /// Removes a file from the attachment queue.
  void removeAttachment(XFile file) {
    _attachmentDrafts.remove(file);
    notifyListeners();
  }

  /// Clears all queued attachments.
  void clearAttachments() {
    _attachmentDrafts.clear();
    notifyListeners();
  }

  /// Convenience method for file picker callbacks.
  void attachFile(XFile file) => addAttachment(file);

  /// Convenience method for platform file picker.
  void attachFileFromPlatform(PlatformFile file) {
    if (file.path != null) {
      addAttachment(XFile(file.path!, name: file.name));
    }
  }

  // ===========================================================================
  // EDITING STATE
  // ===========================================================================

  Event? _editingEvent;
  Event? get editingEvent => _editingEvent;

  void startEditing(Event event) {
    _editingEvent = event;
    _replyingTo = null; // Cannot reply while editing
    notifyListeners();
  }

  void cancelEditing() {
    _editingEvent = null;
    notifyListeners();
  }

  // ===========================================================================
  // REPLY
  // ===========================================================================

  /// Sets the event to reply to.
  void setReplyTo(Event? event) {
    _replyingTo = event;
    _editingEvent = null; // Cannot edit while replying
    notifyListeners();
  }

  // ===========================================================================
  // SENDING MESSAGES
  // ===========================================================================

  /// Sends a text message with any queued attachments.
  ///
  /// Clears UI state immediately for responsive feedback.
  Future<void> sendMessage(String text) async {
    final trimmedText = text.trim();
    final hasAttachments = _attachmentDrafts.isNotEmpty;
    if (trimmedText.isEmpty && !hasAttachments) return;

    // Handle Edit
    if (_editingEvent != null) {
      final originalId = _editingEvent!.eventId;

      // Optimistic cleanup
      _editingEvent = null;
      notifyListeners();

      await _chatRepository.editTextMessage(
        room: room,
        originalEventId: originalId,
        newText: trimmedText,
      );
      return;
    }

    final replyTo = _replyingTo;
    final attachmentsToSend = List<XFile>.from(_attachmentDrafts);

    // Clear UI state immediately for responsiveness
    _replyingTo = null;
    _attachmentDrafts.clear();
    notifyListeners();

    // Send attachments first
    if (attachmentsToSend.isNotEmpty) {
      await sendFiles(attachmentsToSend, compress: true, replyTo: replyTo);
    }

    // Send text (only first message is a reply if there were attachments)
    if (trimmedText.isNotEmpty) {
      await _chatRepository.sendTextMessage(
        room: room,
        text: trimmedText,
        inReplyTo: attachmentsToSend.isEmpty ? replyTo : null,
      );
    }
  }

  Future<void> redactEvent(String eventId) async {
    await _chatRepository.redactMessage(room: room, eventId: eventId);
  }

  /// Sends files with optional compression.
  ///
  /// Images (except GIFs) larger than 20KB are compressed to max 1600px.
  Future<void> sendFiles(
    List<XFile> files, {
    bool compress = true,
    Event? replyTo,
  }) async {
    final uploadedAssets = <_UploadedAsset>[];

    // Phase 1: Upload files
    for (final file in files) {
      final asset = await _uploadFile(file, compress: compress);
      if (asset != null) {
        uploadedAssets.add(asset);
      }
    }

    // Phase 2: Send file events
    var replyEventUsed = replyTo;
    for (final asset in uploadedAssets) {
      final result = await _chatRepository.sendFileMessage(
        room: room,
        mxcUri: asset.uri,
        filename: asset.name,
        msgType: asset.msgType,
        size: asset.size,
        mimeType: asset.mime,
        inReplyTo: replyEventUsed,
      );

      result.fold(
        (_) => replyEventUsed = null, // Only first file is a reply
        (e) {
          _log.severe('Failed to send file message', e);
          _errorController.add('Failed to send file: $e');
        },
      );
    }
  }

  Future<_UploadedAsset?> _uploadFile(
    XFile file, {
    required bool compress,
  }) async {
    _addToProcessing(file.name);

    try {
      final mime = lookupMimeType(file.path);
      var uploadMime = mime;
      Uint8List? uploadBytes;
      String? uploadPath = file.path;
      var uploadSize = 0;

      // Compress images if enabled (except GIFs)
      if (compress && _shouldCompress(mime)) {
        final originalBytes = await compute(_readBytes, file.path);
        if (originalBytes.length > 20000) {
          _log.fine('Compressing: ${file.name}');
          final compressed = await _compressImageIsolate(originalBytes);
          if (compressed != null) {
            uploadBytes = compressed.bytes;
            uploadMime = compressed.mimeType;
            uploadSize = compressed.bytes.length;
            uploadPath = null;
          }
        }
      }

      // Get file size if not compressed
      if (uploadSize == 0) {
        uploadSize = await File(file.path).length();
      }

      // Upload
      final result = await _chatRepository.uploadContent(
        bytes: uploadBytes,
        filename: file.name,
        contentType: uploadMime,
        filePath: uploadPath,
      );

      return result.fold(
        (uri) => _UploadedAsset(
          uri: uri,
          name: file.name,
          mime: uploadMime,
          size: uploadSize,
        ),
        (e) {
          _log.severe('Upload failed: ${file.name}', e);
          _errorController.add('Failed to upload ${file.name}: $e');
          return null;
        },
      );
    } catch (e, s) {
      _log.severe('Upload error: ${file.name}', e, s);
      _errorController.add('Error uploading ${file.name}: $e');
      return null;
    } finally {
      _removeFromProcessing(file.name);
    }
  }

  bool _shouldCompress(String? mime) {
    return mime != null && mime.startsWith('image/') && !mime.contains('gif');
  }

  void _addToProcessing(String name) {
    _processingFiles.add(name);
    notifyListeners();
  }

  void _removeFromProcessing(String name) {
    _processingFiles.remove(name);
    notifyListeners();
  }

  // ===========================================================================
  // TYPING INDICATOR
  // ===========================================================================

  // ===========================================================================
  // TYPING INDICATOR
  // ===========================================================================

  /// Updates typing indicator with debouncing.
  void updateTyping(bool isTyping) {
    if (!MatrixService().sendTypingIndicators) return;

    final now = DateTime.now();
    final shouldThrottle =
        _lastTypingTime != null &&
        now.difference(_lastTypingTime!) < const Duration(milliseconds: 1000) &&
        isTyping;

    if (shouldThrottle) return;

    _lastTypingTime = now;
    _chatRepository.setTyping(room, isTyping);
  }

  // ===========================================================================
  // READ MARKERS
  // ===========================================================================

  /// Updates scroll position state.
  void setScrolledUp(bool isScrolledUp) {
    _scrolledUp = isScrolledUp;
    if (!_scrolledUp) {
      setReadMarker();
    }
  }

  /// Sets read marker using Timeline.
  ///
  /// Timeline.setReadMarker updates local state immediately,
  /// unlike Room.setReadMarker which waits for sync.
  void setReadMarker({String? eventId}) {
    if (!MatrixService().sendReadReceipts) return;

    if (_setReadMarkerFuture != null) return;
    if (_scrolledUp) return;
    if (eventId == null &&
        !room.hasNewMessages &&
        room.notificationCount == 0) {
      return;
    }

    // Don't send markers when app is in background
    if (!kIsWeb &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final tl = timeline;
    if (tl == null || tl.events.isEmpty) return;

    _log.fine('Setting read marker...');

    _setReadMarkerFuture = tl
        .setReadMarker(eventId: eventId)
        .then((_) {
          _setReadMarkerFuture = null;
          _log.fine('Read marker set');
        })
        .catchError((Object e) {
          _setReadMarkerFuture = null;
          _log.warning('Read marker failed', e);
        });
  }

  /// Forces read marker to be set (for exit scenarios).
  Future<void> forceSetReadMarker() async {
    final tl = timeline;

    if (tl == null || tl.events.isEmpty) {
      // Fallback to room.setReadMarker
      final lastEventId = room.lastEvent?.eventId;
      if (lastEventId != null) {
        try {
          await room.setReadMarker(lastEventId);
          room.notificationCount = 0;
          room.highlightCount = 0;
        } catch (e) {
          _log.warning('Force read marker failed', e);
        }
      }
      return;
    }

    try {
      await tl.setReadMarker();
      _log.fine('Force read marker set');
    } catch (e) {
      _log.warning('Force read marker failed', e);
    }
  }
}

// =============================================================================
// HELPER TYPES
// =============================================================================

/// Represents an uploaded file asset.
class _UploadedAsset {
  final Uri uri;
  final String name;
  final String? mime;
  final int size;

  const _UploadedAsset({
    required this.uri,
    required this.name,
    required this.mime,
    required this.size,
  });

  /// Determines message type based on MIME type.
  String get msgType {
    if (mime == null) return MessageTypes.File;
    if (mime!.startsWith('image/')) return MessageTypes.Image;
    if (mime!.startsWith('video/')) return MessageTypes.Video;
    if (mime!.startsWith('audio/')) return MessageTypes.Audio;
    return MessageTypes.File;
  }
}
