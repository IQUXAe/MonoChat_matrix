import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logging/logging.dart';

/// Message types for isolate communication
sealed class IsolateMessage {}

class UploadRequest extends IsolateMessage {
  final String id;
  final String uploadUrl;
  final String filePath; // Changed from bytes to filePath
  final String filename;
  final String? contentType;
  final Map<String, String> headers;

  UploadRequest({
    required this.id,
    required this.uploadUrl,
    required this.filePath,
    required this.filename,
    this.contentType,
    required this.headers,
  });
}

class UploadResponse extends IsolateMessage {
  final String id;
  final String? mxcUri;
  final String? error;

  UploadResponse({required this.id, this.mxcUri, this.error});

  bool get isSuccess => mxcUri != null;
}

class ShutdownRequest extends IsolateMessage {}

/// Runs file uploads in a background isolate to prevent UI jank.
///
/// Uses raw HTTP to upload files to Matrix media endpoint,
/// bypassing the main-thread Matrix SDK client.
class BackgroundUploader {
  static final Logger _log = Logger('BackgroundUploader');

  Isolate? _isolate;
  SendPort? _sendPort;
  final _responseController = StreamController<UploadResponse>.broadcast();
  final Completer<void> _ready = Completer<void>();

  /// Stream of upload responses
  Stream<UploadResponse> get responses => _responseController.stream;

  /// Initialize the background isolate
  Future<void> init() async {
    if (_isolate != null) return;

    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(_isolateEntryPoint, receivePort.sendPort);

    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _ready.complete();
      } else if (message is UploadResponse) {
        _responseController.add(message);
      }
    });

    await _ready.future;
    _log.info('Background uploader initialized');
  }

  /// Upload a file in the background
  /// Returns the request ID for tracking
  String upload({
    required String uploadUrl,
    required String filePath,
    required String filename,
    String? contentType,
    required Map<String, String> headers,
  }) {
    if (_sendPort == null) {
      throw StateError('BackgroundUploader not initialized');
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    _sendPort!.send(
      UploadRequest(
        id: id,
        uploadUrl: uploadUrl,
        filePath: filePath,
        filename: filename,
        contentType: contentType,
        headers: headers,
      ),
    );

    return id;
  }

  /// Upload and wait for result
  Future<UploadResponse> uploadAndWait({
    required String uploadUrl,
    required String filePath,
    required String filename,
    String? contentType,
    required Map<String, String> headers,
  }) async {
    final id = upload(
      uploadUrl: uploadUrl,
      filePath: filePath,
      filename: filename,
      contentType: contentType,
      headers: headers,
    );

    return responses.firstWhere((r) => r.id == id);
  }

  /// Shutdown the isolate
  void dispose() {
    _sendPort?.send(ShutdownRequest());
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _responseController.close();
  }

  /// Isolate entry point - runs in background thread
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is UploadRequest) {
        final response = await _performUpload(message);
        mainSendPort.send(response);
      } else if (message is ShutdownRequest) {
        receivePort.close();
        Isolate.exit();
      }
    });
  }

  /// Perform the actual HTTP upload
  static Future<UploadResponse> _performUpload(UploadRequest request) async {
    try {
      final file = File(request.filePath);
      if (!file.existsSync()) {
        return UploadResponse(
          id: request.id,
          error: 'File not found: ${request.filePath}',
        );
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(
        minutes: 5,
      ); // Increased timeout for large files

      final uri = Uri.parse(request.uploadUrl);
      final httpRequest = await client.postUrl(uri);

      // Set headers
      request.headers.forEach((key, value) {
        httpRequest.headers.set(key, value);
      });

      if (request.contentType != null) {
        httpRequest.headers.contentType = ContentType.parse(
          request.contentType!,
        );
      }

      final length = await file.length();
      httpRequest.headers.contentLength = length;

      // Stream body (avoids loading into memory)
      await httpRequest.addStream(file.openRead());

      // Get response
      final response = await httpRequest.close();
      final responseBody = await response
          .transform(const SystemEncoding().decoder)
          .join();

      client.close();

      if (response.statusCode == 200) {
        // Parse MXC URI from response
        // Response format: {"content_uri": "mxc://..."}
        final match = RegExp(
          r'"content_uri"\s*:\s*"([^"]+)"',
        ).firstMatch(responseBody);
        if (match != null) {
          return UploadResponse(id: request.id, mxcUri: match.group(1));
        }
        return UploadResponse(
          id: request.id,
          error: 'Failed to parse response: $responseBody',
        );
      } else {
        return UploadResponse(
          id: request.id,
          error: 'HTTP ${response.statusCode}: $responseBody',
        );
      }
    } catch (e) {
      return UploadResponse(id: request.id, error: e.toString());
    }
  }
}

/// Singleton instance
final backgroundUploader = BackgroundUploader();
