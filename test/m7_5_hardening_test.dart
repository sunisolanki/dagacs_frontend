import 'dart:convert';

import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/models/report_page.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// M7.5 production-hardening tests — purely additive.
///
/// 1. Standardized error-message mapping via userMessageFor (raw backend text
///    never surfaced for 401/403/404/500; safe validation text kept for 400/409)
/// 2. Unauthorized (401) redirect hook fires (session lifecycle)
/// 3. Session persistence restore / clear
/// 4. ReportPage pagination metadata
///
/// HOD report pagination button enabled/disabled state tests were added to
/// test/screens/hod_reports_screen_test.dart (the existing HOD test
/// infrastructure), since the frozen M7.3 screen is not part of this file.

class _MockClient extends http.BaseClient {
  _MockClient(this._handler);
  final http.Response Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final resp = _handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(resp.body)),
      resp.statusCode,
      headers: resp.headers,
    );
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

void _mockSecureStorage(String? token) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'write':
        return null;
      case 'read':
        final args = call.arguments as Map;
        final key = args['key'] as String;
        return key == 'access_token' ? token : null;
      case 'delete':
        return null;
      default:
        return null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M7.5 - standardized error message mapping', () {
    test('userMessageFor maps network to Unable to connect', () {
      expect(userMessageFor(const ApiException.network()),
          'Unable to connect. Check your internet connection.');
    });

    test('userMessageFor maps 403 to not-authorized text', () {
      expect(userMessageFor(const ApiException.forbidden()),
          'You are not authorized to perform this action.');
    });

    test('userMessageFor maps 404 to not-found text', () {
      expect(userMessageFor(const ApiException.notFound()),
          'Requested data was not found.');
    });

    test('userMessageFor maps 500 to generic server text', () {
      expect(userMessageFor(const ApiException.serverError()),
          'Something went wrong. Please try again.');
    });

    test('userMessageFor never exposes raw backend text for 500s', () {
      final raw = const ApiException(500, 'Internal db_0091 deadlock trace');
      expect(userMessageFor(raw), 'Something went wrong. Please try again.');
      expect(userMessageFor(raw), isNot(contains('deadlock')));
    });

    test('400/409 keep their safe backend validation messages', () {
      expect(userMessageFor(const ApiException(400, 'Name is required')),
          'Name is required');
      expect(
          userMessageFor(const ApiException(409, 'Already exists')),
          'Already exists');
    });
  });

  group('M7.5 - unauthorized (401) lifecycle redirect hook', () {
    test('401 invokes onUnauthorized exactly once', () async {
      var redirects = 0;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        onUnauthorized: () => redirects++,
        httpClient: _MockClient((req) => http.Response('{}', 401)),
      );
      try {
        await client.get('/x');
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.message, 'Session expired. Please sign in again.');
      }
      expect(redirects, 1);
    });

    test('401 response never surfaces raw backend body text', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        onUnauthorized: () {},
        httpClient: _MockClient(
            (req) => http.Response('{"message":"raw token rejected"}', 401)),
      );
      try {
        await client.get('/x');
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.message, isNot(contains('raw token rejected')));
      }
    });
  });

  group('M7.5 - session persistence lifecycle', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues({
        'user_role': 'ADMIN',
        'user_email': 'admin@dagacs.local',
        'user_full_name': 'Admin',
      });
      _mockSecureStorage('persisted-jwt');
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });

    test('restoreSession restores authenticated state from token', () async {
      final session = SessionController(_FakeAuthRepository());
      await session.restoreSession();
      expect(session.initialized, isTrue);
      expect(session.isAuthenticated, isTrue);
      expect(session.role, 'ADMIN');
      expect(session.email, 'admin@dagacs.local');
    });

    test('clearSession resets persisted state to unauthenticated', () async {
      final session = SessionController(_FakeAuthRepository());
      await session.restoreSession();
      expect(session.isAuthenticated, isTrue);

      await session.clearSession();
      expect(session.isAuthenticated, isFalse);
      expect(session.email, isNull);
    });
  });

  group('M7.5 - report page model pagination metadata', () {
    test('ReportPage exposes page and totalPages for pagination UI', () {
      final page = ReportPage<String>.fromJson({
        'content': [
          {'v': 'a'},
          {'v': 'b'},
        ],
        'number': 2,
        'totalPages': 5,
      }, (json) => json['v'] as String);
      expect(page.page, 2);
      expect(page.totalPages, 5);
      expect(page.items, ['a', 'b']);
    });

    test('ReportPage handles missing content defensively', () {
      final page = ReportPage<String>.fromJson({}, (json) => json['v'] as String);
      expect(page.items, isEmpty);
      expect(page.page, 0);
      expect(page.totalPages, 0);
    });
  });
}
