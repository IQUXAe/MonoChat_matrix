import 'package:flutter_test/flutter_test.dart';
import 'package:monochat/core/exceptions/app_exception.dart';
import 'package:monochat/core/result.dart';

void main() {
  group('Result', () {
    group('Success', () {
      test('isSuccess returns true', () {
        const result = Success(42);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('valueOrNull returns the value', () {
        const result = Success('hello');
        expect(result.valueOrNull, 'hello');
      });

      test('exceptionOrNull returns null', () {
        const result = Success(42);
        expect(result.exceptionOrNull, isNull);
      });

      test('fold calls onSuccess', () {
        const result = Success(10);
        final value = result.fold((v) => v * 2, (e) => -1);
        expect(value, 20);
      });

      test('getOrThrow returns value', () {
        const result = Success('test');
        expect(result.getOrThrow(), 'test');
      });

      test('map transforms the value', () {
        const result = Success(5);
        final mapped = result.map((v) => v.toString());
        expect(mapped.valueOrNull, '5');
      });
    });

    group('Failure', () {
      test('isFailure returns true', () {
        const result = Failure<int>(GenericException('error'));
        expect(result.isFailure, isTrue);
        expect(result.isSuccess, isFalse);
      });

      test('valueOrNull returns null', () {
        const result = Failure<String>(GenericException('error'));
        expect(result.valueOrNull, isNull);
      });

      test('exceptionOrNull returns the exception', () {
        const exception = GenericException('test error');
        const result = Failure<int>(exception);
        expect(result.exceptionOrNull, exception);
      });

      test('fold calls onFailure', () {
        const result = Failure<int>(GenericException('error'));
        final value = result.fold((v) => v * 2, (e) => -1);
        expect(value, -1);
      });

      test('getOrThrow throws the exception', () {
        const result = Failure<int>(GenericException('test'));
        expect(() => result.getOrThrow(), throwsA(isA<GenericException>()));
      });

      test('getOrElse returns the default value', () {
        const result = Failure<int>(GenericException('error'));
        expect(result.getOrElse(99), 99);
      });

      test('map preserves the failure', () {
        const result = Failure<int>(GenericException('error'));
        final mapped = result.map((v) => v.toString());
        expect(mapped.isFailure, isTrue);
      });
    });
  });

  group('AppException', () {
    test('GenericException has correct userMessage', () {
      const e = GenericException('Test message');
      expect(e.userMessage, 'Test message');
    });

    test('NetworkException has correct userMessage', () {
      const e = NetworkException('Connection failed');
      expect(e.userMessage, contains('Unable to connect'));
    });

    test('InvalidCredentialsException has correct userMessage', () {
      const e = InvalidCredentialsException();
      expect(e.userMessage, contains('Invalid username or password'));
    });

    test('MessageSendFailedException has correct userMessage', () {
      const e = MessageSendFailedException();
      expect(e.userMessage, contains('Failed to send message'));
    });

    test('FileUploadFailedException includes filename', () {
      const e = FileUploadFailedException(filename: 'photo.jpg');
      expect(e.userMessage, contains('photo.jpg'));
    });
  });
}
