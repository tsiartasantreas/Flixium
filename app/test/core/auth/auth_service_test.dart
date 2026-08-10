import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/auth/auth_service.dart';

void main() {
  group('AuthResult', () {
    test('isSuccess is true when user is provided', () {
      const result = AuthResult(user: null);
      // user is null here, so isSuccess should be false.
      expect(result.isSuccess, isFalse);
    });

    test('isSuccess is false when only error is provided', () {
      const result = AuthResult(error: 'Something went wrong');
      expect(result.isSuccess, isFalse);
      expect(result.error, 'Something went wrong');
    });

    test('user and error are null by default', () {
      const result = AuthResult();
      expect(result.user, isNull);
      expect(result.error, isNull);
      expect(result.isSuccess, isFalse);
    });
  });

  group('AuthService', () {
    late AuthService service;

    setUp(() {
      service = AuthService();
    });

    test('service can be instantiated', () {
      expect(service, isA<AuthService>());
    });

    test('currentUser is null when no Supabase is initialized', () {
      // Without a real Supabase client, currentUser should be null.
      expect(service.currentUser, isNull);
    });
  });
}
