import 'package:matrix/matrix.dart' hide Result;
import 'package:mocktail/mocktail.dart';

import 'package:monochat/core/result.dart';
import 'package:monochat/domain/repositories/auth_repository.dart';
import 'package:monochat/domain/repositories/chat_repository.dart';
import 'package:monochat/domain/repositories/room_repository.dart';

// =============================================================================
// Repository Mocks
// =============================================================================

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRoomRepository extends Mock implements RoomRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

// =============================================================================
// Matrix SDK Mocks
// =============================================================================

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockEvent extends Mock implements Event {}

class MockTimeline extends Mock implements Timeline {}

// =============================================================================
// Fallback Values
// =============================================================================

/// Register fallback values for mocktail.
/// Call this in setUpAll() of your test files.
void registerFallbackValues() {
  registerFallbackValue(Uri.parse('mxc://example.com/test'));
  registerFallbackValue(MockRoom());
  registerFallbackValue(MockEvent());
  registerFallbackValue(const Success<void>(null));
}
