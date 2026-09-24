import 'dart:convert';

import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/student_profile_repository.dart';
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

ApiClient _clientReturning(int status, [String body = '']) {
  return ApiClient(
    baseUrl: 'http://test.local/api',
    tokenProvider: () async => 'token',
    httpClient: _MockClient(
        (req) => http.Response(body, status,
            headers: {'content-type': 'application/json'})),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentProfileRepository.getMyProfile', () {
    test('sends GET to student/profile', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response(
              '{"name":"Student User"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentProfileRepository(client);
      await repo.getMyProfile();
      expect(seenPath, '/api/student/profile');
    });

    test('parses profile fields', () async {
      final client = _clientReturning(200, '{"rollNumber":"2201CE001",'
           '"name":"Student User","batchName":"B1",'
           '"programName":"Computer Science","sectionName":"A",'
           '"personalEmail":"student@test.com"}');
      final repo = StudentProfileRepository(client);
      final profile = await repo.getMyProfile();
      expect(profile.rollNumber, '2201CE001');
      expect(profile.name, 'Student User');
      expect(profile.batchName, 'B1');
      expect(profile.programName, 'Computer Science');
      expect(profile.sectionName, 'A');
      expect(profile.personalEmail, 'student@test.com');
    });

    test('throws ApiException on 401', () async {
      final client = _clientReturning(401, '{"error":"Unauthorized"}');
      final repo = StudentProfileRepository(client);
      expect(
        repo.getMyProfile(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('throws ApiException on 403', () async {
      final client = _clientReturning(403, '{"error":"Forbidden"}');
      final repo = StudentProfileRepository(client);
      expect(
        repo.getMyProfile(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('throws serverError when response is not a JSON object', () async {
      final client = _clientReturning(200, '[]');
      final repo = StudentProfileRepository(client);
      expect(
        repo.getMyProfile(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });

  group('StudentProfileRepository.updateMyProfile', () {
    test('sends PUT to student/profile', () async {
      String? seenPath;
      String? seenBody;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenBody = req.body;
          return http.Response('{"name":"Updated"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentProfileRepository(client);
      await repo.updateMyProfile({'fatherName': 'New Father', 'personalEmail': 'newemail@test.com'});
      expect(seenPath, '/api/student/profile');
      expect(seenBody, contains('fatherName'));
      expect(seenBody, contains('personalEmail'));
    });

    test('updates profile fields', () async {
      final client = _clientReturning(200, '{"rollNumber":"2201CE001",'
           '"name":"Updated Name","batchName":"B1",'
           '"programName":"Computer Science","sectionName":"A",'
           '"personalEmail":"newemail@test.com"}');
      final repo = StudentProfileRepository(client);
      final profile = await repo.updateMyProfile({
        'fatherName': 'New Father',
        'motherName': 'New Mother',
        'personalEmail': 'newemail@test.com',
      });
      expect(profile.rollNumber, '2201CE001');
      expect(profile.name, 'Updated Name');
      expect(profile.personalEmail, 'newemail@test.com');
    });

    test('throws ApiException on 401', () async {
      final client = _clientReturning(401, '{"error":"Unauthorized"}');
      final repo = StudentProfileRepository(client);
      expect(
        repo.updateMyProfile({'fatherName': 'New Father'}),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('throws serverError when response is not a JSON object', () async {
      final client = _clientReturning(200, '[]');
      final repo = StudentProfileRepository(client);
      expect(
        repo.updateMyProfile({'fatherName': 'New Father'}),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
