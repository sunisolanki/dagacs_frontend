import 'dart:convert';

import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
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

  group('AuthRepository.login 401 handling (M8 F-21)', () {
    test('throws ApiException.unauthorized and does NOT invoke global onUnauthorized',
        () async {
      var unauthorizedCalled = false;
      final apiClient = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => null,
        onUnauthorized: () => unauthorizedCalled = true,
        httpClient: _MockClient((req) => http.Response('{"message":"Invalid email or password"}', 401)),
      );
      final repository = AuthRepository(apiClient);

      try {
        await repository.login('admin@dagacs.local', 'WrongPass1');
        fail('expected ApiException 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
      expect(unauthorizedCalled, isFalse);
    });

    test('successful login parses AuthResponse unchanged and never fires onUnauthorized',
        () async {
      var unauthorizedCalled = false;
      final apiClient = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => null,
        onUnauthorized: () => unauthorizedCalled = true,
        httpClient: _MockClient((req) => http.Response(
          '{"token":"jwt-token","role":"ADMIN","email":"admin@dagacs.local","fullName":"Admin User"}',
          200,
          headers: {'content-type': 'application/json'},
        )),
      );
      final repository = AuthRepository(apiClient);

      final auth = await repository.login('admin@dagacs.local', 'Admin@123');
      expect(auth.token, 'jwt-token');
      expect(auth.role, 'ADMIN');
      expect(auth.email, 'admin@dagacs.local');
      expect(auth.fullName, 'Admin User');
      expect(unauthorizedCalled, isFalse);
    });
  });
}