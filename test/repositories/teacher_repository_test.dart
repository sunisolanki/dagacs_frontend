import 'dart:convert';

import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
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

const _assignmentJson = '[{"id":7,"teacherId":2,"teacherName":"Dr A Sharma",'
    '"teacherEmail":"a@college.edu",'
    '"subjectOfferingId":5,"subjectId":4,"subjectCode":"CS301",'
    '"subjectName":"DBMS","semesterId":3,"semesterName":"Semester 3",'
    '"sessionId":1,"sessionName":"2026-27","programId":8,'
    '"programName":"B.Tech CSE","departmentId":2,'
    '"departmentName":"Computer Science","sectionId":9,'
    '"sectionCode":"A","sectionName":"Section A","batchId":6,'
    '"batchCode":"B1","createdAt":"2026-09-01T10:00:00Z",'
    '"updatedAt":"2026-09-01T10:00:00Z"}]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TeacherRepository.getMyAssignments', () {
    test('GETs /api/teacher/assignments and parses the full DTO list',
        () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'teacher-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(_assignmentJson, 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = TeacherRepository(client);
      final list = await repo.getMyAssignments();

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/teacher/assignments');
      expect(seen.url.query, isEmpty);
      expect(
        seen.headers['Authorization'],
        'Bearer teacher-token',
      );
      expect(list, hasLength(1));
      final a = list.single;
      expect(a.id, 7);
      expect(a.teacherId, 2);
      expect(a.teacherName, 'Dr A Sharma');
      expect(a.teacherEmail, 'a@college.edu');
      expect(a.subjectOfferingId, 5);
      expect(a.subjectId, 4);
      expect(a.subjectCode, 'CS301');
      expect(a.subjectName, 'DBMS');
      expect(a.semesterId, 3);
      expect(a.semesterName, 'Semester 3');
      expect(a.sessionId, 1);
      expect(a.sessionName, '2026-27');
      expect(a.programId, 8);
      expect(a.programName, 'B.Tech CSE');
      expect(a.departmentId, 2);
      expect(a.departmentName, 'Computer Science');
      expect(a.sectionId, 9);
      expect(a.sectionCode, 'A');
      expect(a.sectionName, 'Section A');
      expect(a.batchId, 6);
      expect(a.batchCode, 'B1');
    });

    test('returns an empty list for an empty array', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'teacher-token',
        httpClient: _MockClient((req) => http.Response('[]', 200,
            headers: {'content-type': 'application/json'})),
      );
      final repo = TeacherRepository(client);
      expect(await repo.getMyAssignments(), isEmpty);
    });

    test('propagates a 403 Forbidden', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'teacher-token',
        httpClient: _MockClient((req) => http.Response('{"error":"Forbidden"}',
            403, headers: {'content-type': 'application/json'})),
      );
      final repo = TeacherRepository(client);
      expect(
        repo.getMyAssignments(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('propagates a 401 Unauthorized', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => null,
        onUnauthorized: () {},
        httpClient: _MockClient((req) => http.Response('{"error":"Unauthed"}',
            401, headers: {'content-type': 'application/json'})),
      );
      final repo = TeacherRepository(client);
      expect(
        repo.getMyAssignments(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('maps a non-list 200 body to a server error', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'teacher-token',
        httpClient: _MockClient((req) => http.Response('{"id":1}', 200,
            headers: {'content-type': 'application/json'})),
      );
      final repo = TeacherRepository(client);
      expect(
        repo.getMyAssignments(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}