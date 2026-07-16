import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fyp/dataAccessLayer/repositories/auth_repository.dart';
import 'package:fyp/utils/validators.dart';

void main() {
  test('duplicate signup responses are recognized without another account', () {
    final existingAccount = AuthResponse(
      user: const User(
        id: 'obfuscated-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        email: 'member@example.com',
        createdAt: '2026-07-17T00:00:00Z',
        identities: [],
      ),
    );
    final newUnconfirmedAccount = AuthResponse(
      user: const User(
        id: 'new-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        email: 'new@example.com',
        createdAt: '2026-07-17T00:00:00Z',
      ),
    );

    expect(AuthRepository.isExistingAccountSignup(existingAccount), isTrue);
    expect(
      AuthRepository.isExistingAccountSignup(newUnconfirmedAccount),
      isFalse,
    );
  });

  test('email verification accepts exactly eight digits', () {
    expect(AppValidators.emailVerificationCode('12345678'), isNull);
    expect(AppValidators.emailVerificationCode('123456'), isNotNull);
    expect(AppValidators.emailVerificationCode('1234567a'), isNotNull);
  });

  test('signup email codes are verified with the email OTP type', () async {
    late http.BaseRequest capturedRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Request captured'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    final repository = AuthRepository(client: client);

    await expectLater(
      repository.verifySignupCode(
        email: 'new.user@example.com',
        token: '12345678',
        redirectTo: 'io.supabase.flutter://login-callback/',
      ),
      throwsA(isA<AuthException>()),
    );

    expect(capturedRequest.url.path, '/auth/v1/verify');
    final body = jsonDecode((capturedRequest as http.Request).body);
    expect(body['email'], 'new.user@example.com');
    expect(body['token'], '12345678');
    expect(body['type'], 'email');
  });

  test('password reset requests use the recovery endpoint', () async {
    late http.BaseRequest capturedRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200, headers: {
          'content-type': 'application/json',
        });
      }),
    );
    addTearDown(client.dispose);

    final repository = AuthRepository(client: client);
    await repository.requestPasswordReset(
      email: 'member@example.com',
      redirectTo: 'io.supabase.flutter://login-callback/',
    );

    expect(capturedRequest.url.path, '/auth/v1/recover');
    final body = jsonDecode((capturedRequest as http.Request).body);
    expect(body['email'], 'member@example.com');
  });

  test('password reset codes are verified as recovery OTPs', () async {
    late http.BaseRequest capturedRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Request captured'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    final repository = AuthRepository(client: client);
    await expectLater(
      repository.verifyPasswordRecoveryCode(
        email: 'member@example.com',
        token: '12345678',
        redirectTo: 'io.supabase.flutter://login-callback/',
      ),
      throwsA(isA<AuthException>()),
    );

    expect(capturedRequest.url.path, '/auth/v1/verify');
    final body = jsonDecode((capturedRequest as http.Request).body);
    expect(body['email'], 'member@example.com');
    expect(body['token'], '12345678');
    expect(body['type'], 'recovery');
  });
}
