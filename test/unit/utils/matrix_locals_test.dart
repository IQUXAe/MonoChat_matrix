import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/utils/matrix_locals.dart';

class MockAppLocalizations extends Mock implements AppLocalizations {}

class MockEvent extends Mock implements Event {}

void main() {
  late MockAppLocalizations mockL10n;
  late MatrixLocals matrixLocals;

  setUp(() {
    mockL10n = MockAppLocalizations();
    matrixLocals = MatrixLocals(mockL10n);
  });

  group('MatrixLocals', () {
    test('you delegates to l10n.you', () {
      when(() => mockL10n.you).thenReturn('Mock You');
      expect(matrixLocals.you, 'Mock You');
      verify(() => mockL10n.you).called(1);
    });

    test('anyoneCanJoin delegates to l10n.anyoneCanJoin', () {
      when(() => mockL10n.anyoneCanJoin).thenReturn('Mock Anyone Can Join');
      expect(matrixLocals.anyoneCanJoin, 'Mock Anyone Can Join');
      verify(() => mockL10n.anyoneCanJoin).called(1);
    });

    test('unknownUser delegates to l10n.unknownUser', () {
      when(() => mockL10n.unknownUser).thenReturn('Mock Unknown User');
      expect(matrixLocals.unknownUser, 'Mock Unknown User');
      verify(() => mockL10n.unknownUser).called(1);
    });

    test('hardcoded strings return expected values', () {
      expect(matrixLocals.guestsAreForbidden, 'Guests are forbidden');
      expect(matrixLocals.guestsCanJoin, 'Guests can join');
      expect(matrixLocals.noPermission, 'No permission');
    });

    test('parameterized methods return correctly formatted strings', () {
      expect(matrixLocals.acceptedTheInvitation('Alice'), 'Alice accepted the invitation');
      expect(matrixLocals.activatedEndToEndEncryption('Bob'), 'Bob activated end-to-end encryption');
      expect(matrixLocals.bannedUser('Alice', 'Bob'), 'Alice banned Bob');
      expect(matrixLocals.changedTheChatNameTo('Alice', 'New Name'), 'Alice changed the chat name to New Name');
    });

    test('redactedAnEvent returns Redacted event', () {
      final mockEvent = MockEvent();
      expect(matrixLocals.redactedAnEvent(mockEvent), 'Redacted event');
    });
  });
}
