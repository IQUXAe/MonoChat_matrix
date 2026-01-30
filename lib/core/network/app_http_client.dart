import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// A custom HTTP client that implements retry logic and improved timeout handling
/// to address "Connection closed" errors.
class AppHttpClient extends http.BaseClient {
  final http.Client _inner;

  AppHttpClient({http.Client? inner})
    : _inner = inner ?? _createDefaultClient();

  static http.Client _createDefaultClient() {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      // Short idle timeout to prevent reusing stale connections that the server might have closed
      ..idleTimeout = const Duration(seconds: 3);
    return IOClient(ioClient);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
