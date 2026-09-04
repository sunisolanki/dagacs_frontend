import 'dart:convert';

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
}
