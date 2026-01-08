/// Base exception class for all application exceptions.
/// Uses sealed class pattern for exhaustive pattern matching.
sealed class AppException implements Exception {
  final String message;
  final String? debugInfo;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.debugInfo, this.stackTrace});

  /// User-friendly message for UI display
  String get userMessage => message;

  @override
  String toString() => 'AppException: $message';
}

/// Generic exception for unclassified errors
class GenericException extends AppException {
  const GenericException(super.message, {super.debugInfo, super.stackTrace});
}

// =============================================================================
// Network Exceptions
// =============================================================================

/// Base class for network-related errors
class NetworkException extends AppException {
  const NetworkException(super.message, {super.debugInfo, super.stackTrace});

  @override
  String get userMessage =>
      'Unable to connect. Please check your internet connection.';
}

/// Server could not be reached
class ServerUnreachableException extends NetworkException {
  final String? homeserver;

  const ServerUnreachableException({this.homeserver, super.debugInfo})
    : super('Server unreachable');

  @override
  String get userMessage => homeserver != null
      ? 'Unable to reach $homeserver. Please check the URL.'
      : 'Unable to reach the server. Please check the URL.';
}

// =============================================================================
// Authentication Exceptions
// =============================================================================

/// Base class for authentication-related errors
class AuthException extends AppException {
  const AuthException(super.message, {super.debugInfo, super.stackTrace});
}

/// Invalid username or password
class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException({super.debugInfo})
    : super('Invalid username or password');

  @override
  String get userMessage => 'Invalid username or password.';
}

/// Session has expired
class SessionExpiredException extends AuthException {
  const SessionExpiredException({super.debugInfo}) : super('Session expired');

  @override
  String get userMessage => 'Session expired. Please login again.';
}

/// Client initialization failed
class ClientNotInitializedException extends AuthException {
  const ClientNotInitializedException({super.debugInfo})
    : super('Client not initialized');

  @override
  String get userMessage => 'Application failed to initialize. Please restart.';
}

// =============================================================================
// Chat Exceptions
// =============================================================================

/// Base class for chat-related errors
class ChatException extends AppException {
  const ChatException(super.message, {super.debugInfo, super.stackTrace});
}

/// Failed to send a message
class MessageSendFailedException extends ChatException {
  const MessageSendFailedException({super.debugInfo})
    : super('Failed to send message');

  @override
  String get userMessage => 'Failed to send message. Please try again.';
}

/// Failed to upload a file
class FileUploadFailedException extends ChatException {
  final String? filename;

  const FileUploadFailedException({this.filename, super.debugInfo})
    : super('Failed to upload file');

  @override
  String get userMessage => filename != null
      ? 'Failed to upload "$filename".'
      : 'Failed to upload file.';
}

// =============================================================================
// Room Exceptions
// =============================================================================

/// Base class for room-related errors
class RoomException extends AppException {
  const RoomException(super.message, {super.debugInfo, super.stackTrace});
}

/// Room was not found
class RoomNotFoundException extends RoomException {
  final String? roomId;

  const RoomNotFoundException({this.roomId, super.debugInfo})
    : super('Room not found');

  @override
  String get userMessage => 'Room not found.';
}

/// Failed to create a room
class RoomCreationFailedException extends RoomException {
  const RoomCreationFailedException({super.debugInfo})
    : super('Failed to create room');

  @override
  String get userMessage => 'Failed to create chat. Please try again.';
}
