import 'dart:convert';
import 'dart:typed_data';

import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

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

class _DelayedClient extends http.BaseClient {
  _DelayedClient(this.delay);
  final Duration delay;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(delay);
    return http.StreamedResponse(
      Stream.value(const [0x00]),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Simulates a server whose request (connect/send) and body consumption each
/// take time INDEPENDENTLY, so a per-phase timeout chain could hide the real
/// total duration. The M9.14 single-budget contract must still see the sum.
class _SlowBodyClient extends http.BaseClient {
  _SlowBodyClient(this.sendDelay, this.bodyDelay);
  final Duration sendDelay;
  final Duration bodyDelay;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(sendDelay);
    final body = Stream<List<int>>.multi((controller) {
      Future<void>.delayed(bodyDelay).then((_) {
        controller.add(const [0x7B]); // '{'
        controller.close();
      });
    });
    return http.StreamedResponse(body, 200,
        headers: {'content-type': 'application/json'});
  }
}

ApiClient _clientReturning(int status, String body,
    {void Function()? onUnauthorized}) {
  return ApiClient(
    baseUrl: 'http://test.local/api',
    tokenProvider: () async => 'token',
    onUnauthorized: onUnauthorized,
    httpClient: _MockClient((req) =>
        http.Response(body, status, headers: {'content-type': 'application/json'})),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient authorization header', () {
    test('attaches Bearer token to authenticated requests', () async {
      String? seenAuth;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'test-jwt',
        httpClient: _MockClient((req) {
          seenAuth = req.headers['Authorization'];
          return http.Response('[]', 200);
        }),
      );
      await client.get('/admin/departments');
      expect(seenAuth, 'Bearer test-jwt');
    });

    test('omits Authorization header when no token present', () async {
      String? seenAuth = 'unset';
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => null,
        httpClient: _MockClient((req) {
          seenAuth = req.headers['Authorization'];
          return http.Response('[]', 200);
        }),
      );
      await client.get('/admin/departments');
      expect(seenAuth, isNull);
    });
  });

  group('ApiClient status mapping', () {
    ApiClient clientReturning(int status, [String body = '']) {
      return ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient(
            (req) => http.Response(body, status, headers: {
                  'content-type': 'application/json'
                })),
      );
    }

    test('200 returns decoded list', () async {
      final result = await clientReturning(200, '[{"id":1}]').get('/x');
      expect(result, isA<List>());
      expect((result as List).length, 1);
    });

    test('204 returns null', () async {
      final result = await clientReturning(204).delete('/x');
      expect(result, isNull);
    });

    test('201 returns decoded body', () async {
      final result = await clientReturning(201, '{"id":1}').post('/x');
      expect((result as Map)['id'], 1);
    });

    test('400 throws ApiException with message from body', () async {
      try {
        await clientReturning(400, '{"message":"Name is required"}').post('/x');
        fail('expected ApiException 400');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, 'Name is required');
      }
    });

    test('401 throws ApiException and invokes onUnauthorized', () async {
      var unauthorizedCalled = false;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        onUnauthorized: () => unauthorizedCalled = true,
        httpClient: _MockClient((req) => http.Response('{}', 401)),
      );
      try {
        await client.get('/x');
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
      expect(unauthorizedCalled, isTrue);
    });

    test('login 401 with notifyUnauthorized:false throws but does NOT invoke onUnauthorized',
        () async {
      var unauthorizedCalled = false;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        onUnauthorized: () => unauthorizedCalled = true,
        httpClient: _MockClient((req) => http.Response('{}', 401)),
      );
      try {
        await client.post('/auth/login', notifyUnauthorized: false);
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
      expect(unauthorizedCalled, isFalse);
    });

    test('403 throws ApiException.forbidden', () async {
      try {
        await clientReturning(403).get('/x');
        fail('expected ApiException 403');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
      }
    });

    test('404 throws ApiException.notFound', () async {
      try {
        await clientReturning(404).get('/x/999');
        fail('expected ApiException 404');
      } on ApiException catch (e) {
        expect(e.statusCode, 404);
      }
    });

    test('409 throws ApiException.conflict', () async {
      try {
        await clientReturning(409, '{"message":"Already exists"}').post('/x');
        fail('expected ApiException 409');
      } on ApiException catch (e) {
        expect(e.statusCode, 409);
        expect(e.message, 'Already exists');
      }
    });

    test('login 429 throws ApiException with login cooldown and does NOT invoke onUnauthorized',
        () async {
      var unauthorizedCalled = false;
      final client = _clientReturning(
          429, '{"message":"Too many login attempts. Please try again later."}',
          onUnauthorized: () => unauthorizedCalled = true);
      try {
        await client.post('/auth/login',
            notifyUnauthorized: false, isLoginRequest: true);
        fail('expected ApiException 429');
      } on ApiException catch (e) {
        expect(e.statusCode, 429);
        expect(e.message, 'Too many login attempts. Please try again later.');
      }
      expect(unauthorizedCalled, isFalse,
          reason: 'M9.6 M: rate limiting must never trigger the logout hook');
    });

    test('non-login 429 without a body message falls back to the generic rate-limit message',
        () async {
      var unauthorizedCalled = false;
      final client = _clientReturning(429, '',
          onUnauthorized: () => unauthorizedCalled = true);
      try {
        await client.get('/x');
        fail('expected ApiException 429');
      } on ApiException catch (e) {
        expect(e.statusCode, 429);
        expect(e.message, kRateLimitedMessage);
        expect(unauthorizedCalled, isFalse,
            reason: 'M9.14: a non-login 429 must never fire the logout hook');
      }
    });

    test('non-login 429 ignores backend body text and shows the generic rate-limit message',
        () async {
      var unauthorizedCalled = false;
      final client = _clientReturning(
          429, '{"message":"Some unrelated limit"}',
          onUnauthorized: () => unauthorizedCalled = true);
      try {
        await client.get('/x');
        fail('expected ApiException 429');
      } on ApiException catch (e) {
        expect(e.statusCode, 429);
        expect(e.message, kRateLimitedMessage);
        expect(e.message, isNot(contains('login')));
      }
      expect(unauthorizedCalled, isFalse);
    });

    test('login 429 without a body message falls back to the login cooldown string',
        () async {
      final client = _clientReturning(429, '');
      try {
        await client.post('/auth/login',
            notifyUnauthorized: false, isLoginRequest: true);
        fail('expected ApiException 429');
      } on ApiException catch (e) {
        expect(e.statusCode, 429);
        expect(e.message, kTooManyRequestsMessage);
      }
    });

    test('500 throws ApiException.serverError with generic message', () async {
      try {
        await clientReturning(500).get('/x');
        fail('expected ApiException 500');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
      }
    });
  });

  group('ApiClient network failure', () {
    test('network error maps to ApiException.network (-1)', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          throw Exception('connection refused');
        }),
      );
      try {
        await client.get('/x');
        fail('expected ApiException.network');
      } on ApiException catch (e) {
        expect(e.statusCode, -1);
      }
    });
  });

  group('ApiClient timeout (M9.14)', () {
    ApiClient slowClient({void Function()? onUnauthorized}) {
      return ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        onUnauthorized: onUnauthorized,
        timeout: const Duration(milliseconds: 50),
        fileTimeout: const Duration(milliseconds: 50),
        httpClient: _DelayedClient(const Duration(milliseconds: 300)),
      );
    }

    test('GET timeout maps to ApiException.timeout (-2)', () async {
      try {
        await slowClient().get('/x');
        fail('expected ApiException.timeout');
      } on ApiException catch (e) {
        expect(e.statusCode, kTimeoutStatusCode);
        expect(e.message, kTimeoutMessage);
      }
    });

    test('POST timeout maps to ApiException.timeout (-2)', () async {
      try {
        await slowClient().post('/x', body: {'a': 1});
        fail('expected ApiException.timeout');
      } on ApiException catch (e) {
        expect(e.statusCode, kTimeoutStatusCode);
      }
    });

    test('getBytes timeout maps to ApiException.timeout (-2)', () async {
      try {
        await slowClient()
            .getBytes('/hod/reports/daily-lecture/export.xlsx');
        fail('expected ApiException.timeout');
      } on ApiException catch (e) {
        expect(e.statusCode, kTimeoutStatusCode);
      }
    });

    test('postMultipart timeout maps to ApiException.timeout (-2)', () async {
      try {
        await slowClient().postMultipart('/admin/students/import',
            field: 'file', filename: 'students.csv', bytes: const [1, 2, 3]);
        fail('expected ApiException.timeout');
      } on ApiException catch (e) {
        expect(e.statusCode, kTimeoutStatusCode);
      }
    });

    test('timeout never invokes onUnauthorized', () async {
      var unauthorizedCalled = false;
      try {
        await slowClient(onUnauthorized: () => unauthorizedCalled = true)
            .get('/x');
        fail('expected ApiException.timeout');
      } on ApiException {
        // expected
      }
      expect(unauthorizedCalled, isFalse,
          reason: 'M9.14: a timeout is a connectivity problem, not a logout trigger');
    });

    test('ONE overall budget bounds the whole operation, not per-phase',
        () async {
      // send (80 ms) and body consumption (80 ms) are each within a 100 ms
      // per-phase window, but together they exceed the single 100 ms total
      // budget. A per-phase .timeout() chain would let this succeed; the M9.14
      // single-budget contract must time it out.
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        timeout: const Duration(milliseconds: 100),
        fileTimeout: const Duration(milliseconds: 100),
        httpClient: _SlowBodyClient(
            const Duration(milliseconds: 80), const Duration(milliseconds: 80)),
      );
      try {
        await client.get('/x');
        fail('expected ApiException.timeout from a single combined budget');
      } on ApiException catch (e) {
        expect(e.statusCode, kTimeoutStatusCode);
        expect(e.message, kTimeoutMessage);
      }
    });

    test('fast standard requests still succeed within a small budget',
        () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        timeout: const Duration(milliseconds: 50),
        fileTimeout: const Duration(milliseconds: 50),
        httpClient: _MockClient((req) => http.Response('{"ok":true}', 200)),
      );
      final result = await client.get('/x');
      expect(result, {'ok': true});
    });

    test('default budgets remain 15s standard / 60s file transfers', () {
      final client = ApiClient(baseUrl: 'http://test.local/api');
      expect(client.timeout, kStandardRequestTimeout);
      expect(client.fileTimeout, kFileTransferTimeout);
    });
  });

  group('M9.5.4 identity-resolution 401 behaviour (D5)', () {
    test('401 WITHOUT a code invokes onUnauthorized and throws 401', () async {
      var unauthorizedCalled = false;
      final client = _clientReturning(401, '{"message":"Expired"}',
          onUnauthorized: () => unauthorizedCalled = true);
      try {
        await client.get('/teacher/classes');
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.code, isNull);
      }
      expect(unauthorizedCalled, isTrue);
    });

    test('401 WITH an identity code does NOT log out and carries the code',
        () async {
      var unauthorizedCalled = false;
      final client = _clientReturning(
          401,
          '{"code":"TEACHER_PROFILE_INACTIVE",'
          '"message":"Teacher profile is inactive"}',
          onUnauthorized: () => unauthorizedCalled = true);
      try {
        await client.get('/teacher/classes');
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.code, 'TEACHER_PROFILE_INACTIVE');
        expect(e.message, contains('Teacher profile'));
      }
      expect(unauthorizedCalled, isFalse);
    });

    test('non-truthy codes never suppress the logout hook', () async {
      var unauthorizedCalled = false;
      final client = _clientReturning(
          401, '{"code":"SOME_UNKNOWN_CODE","message":"x"}',
          onUnauthorized: () => unauthorizedCalled = true);
      try {
        await client.get('/x');
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.code, 'SOME_UNKNOWN_CODE');
      }
      expect(unauthorizedCalled, isTrue);
    });
  });

  group('M9.5.4 identity message mapping', () {
    test('identity codes map to actionable role-aware messages', () {
      expect(
        messageForIdentityCode('TEACHER_PROFILE_NOT_LINKED'),
        contains('Teacher profile'),
      );
      expect(
        messageForIdentityCode('STUDENT_PROFILE_INACTIVE'),
        contains('Student profile'),
      );
      expect(
        messageForIdentityCode('HOD_NOT_DESIGNATED'),
        contains('HOD'),
      );
      expect(messageForIdentityCode('UNKNOWN'), isNull);
      expect(messageForIdentityCode(null), isNull);
    });

    test('isIdentityResolutionCode recognises the backend codes', () {
      for (final code in kIdentityResolutionCodes) {
        expect(isIdentityResolutionCode(code), isTrue, reason: code);
      }
      expect(isIdentityResolutionCode('WHATEVER'), isFalse);
      expect(isIdentityResolutionCode(null), isFalse);
    });

    test('userMessageFor prefers the identity message over session expiry',
        () {
      final inactive = ApiException(401, 'Teacher profile is inactive',
          code: 'TEACHER_PROFILE_INACTIVE');
      expect(userMessageFor(inactive), contains('Teacher profile'));

      final noCode = ApiException(401, 'Expired');
      expect(userMessageFor(noCode), kSessionExpiredMessage);
    });
  });

  group('ApiClient.getBytes (M7.2 exports)', () {
    test('attaches Bearer token and preserves binary body + headers', () async {
      String? seenAuth;
      String? seenMethod;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'test-jwt',
        httpClient: _MockClient((req) {
          seenAuth = req.headers['Authorization'];
          seenMethod = req.method;
          return http.Response.bytes(
            Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
            200,
            headers: {
              'content-disposition':
                  'attachment; filename="dagacs_hod_daily-lecture_all.pdf"',
              'content-type': 'application/pdf',
            },
          );
        }),
      );
      final response = await client.getBytes('/hod/reports/daily-lecture/export.pdf');
      expect(seenMethod, 'GET');
      expect(seenAuth, 'Bearer test-jwt');
      expect(response.bodyBytes, [0x25, 0x50, 0x44, 0x46]);
      expect(response.headers['content-disposition'],
          'attachment; filename="dagacs_hod_daily-lecture_all.pdf"');
      expect(response.headers['content-type'], 'application/pdf');
    });

    test('400 with message throws ApiException 400', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) =>
            http.Response('{"message":"Unsupported report type"}', 400)),
      );
      try {
        await client.getBytes('/hod/reports/semester/export.xlsx');
        fail('expected ApiException 400');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, 'Unsupported report type');
      }
    });

    test('403 throws ApiException.forbidden', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient:
            _MockClient((req) => http.Response('{"message":"Forbidden"}', 403)),
      );
      try {
        await client.getBytes('/hod/reports/daily-lecture/export.xlsx');
        fail('expected ApiException 403');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
      }
    });

    test('401 throws ApiException and invokes onUnauthorized', () async {
      var unauthorizedCalled = false;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        onUnauthorized: () => unauthorizedCalled = true,
        httpClient: _MockClient((req) => http.Response('{}', 401)),
      );
      try {
        await client.getBytes('/hod/reports/daily-lecture/export.xlsx');
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
      expect(unauthorizedCalled, isTrue);
    });

    test('network failure maps to ApiException.network', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          throw Exception('connection refused');
        }),
      );
      try {
        await client.getBytes('/hod/reports/daily-lecture/export.xlsx');
        fail('expected ApiException.network');
      } on ApiException catch (e) {
        expect(e.statusCode, -1);
      }
    });
  });
}
