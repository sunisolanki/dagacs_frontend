import 'dart:convert';

import 'package:dagacs_frontend/models/attendance_mark_item.dart';
import 'package:dagacs_frontend/models/attendance_mark_request.dart';
import 'package:dagacs_frontend/models/attendance_session_create_request.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
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
        (req) => http.Response(body, status, headers: {
              'content-type': 'application/json'
            })),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttendanceRepository.getSessions', () {
    test('sends GET to teacher/attendance/sessions', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.getSessions();
      expect(seenPath, '/api/teacher/attendance/sessions');
    });

    test('parses session list', () async {
      final client = _clientReturning(200,
          '[{"id":1,"subjectId":5,"subjectName":"DS","sectionId":2,"sectionName":"A","lecturePeriod":"1st","date":"2026-09-04","status":"SCHEDULED"}]');
      final repo = AttendanceRepository(client);
      final sessions = await repo.getSessions();
      expect(sessions.length, 1);
      expect(sessions[0].subjectName, 'DS');
      expect(sessions[0].status, 'SCHEDULED');
    });
  });

  group('AttendanceRepository.createSession', () {
    test('sends POST with JSON body', () async {
      Map<String, dynamic>? body;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
              '{"id":1,"subjectId":5,"status":"SCHEDULED"}', 201,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      final session = await repo.createSession(
        const AttendanceSessionCreateRequest(
            subjectId: 5, sectionId: 2, lecturePeriod: '1st', date: '2026-09-04'),
      );
      expect(body!['subjectId'], 5);
      expect(body!['sectionId'], 2);
      expect(session.status, 'SCHEDULED');
    });
  });

  group('AttendanceRepository.getStudentsForSession', () {
    test('sends GET with session ID in path', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response(
              '[{"id":10,"rollNumber":"R1","name":"Alice"}]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      final students = await repo.getStudentsForSession(1);
      expect(seenPath, '/api/teacher/attendance/sessions/1/students');
      expect(students.length, 1);
      expect(students[0].name, 'Alice');
    });
  });

  group('AttendanceRepository.markAttendance', () {
    test('sends POST with nested body', () async {
      Map<String, dynamic>? body;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
              '[{"id":1,"studentId":10,"status":"PRESENT"}]', 201,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      final records = await repo.markAttendance(
        const AttendanceMarkRequest(
          sessionId: 1,
          items: [
            AttendanceMarkItem(studentId: 10, status: 'PRESENT'),
          ],
        ),
      );
      expect(body!['sessionId'], 1);
      final items = body!['items'] as List;
      expect(items[0]['studentId'], 10);
      expect(items[0]['status'], 'PRESENT');
      expect(records.length, 1);
      expect(records[0].status, 'PRESENT');
    });
  });

  group('AttendanceRepository.getMyAttendance', () {
    test('sends GET to student/attendance/my', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response(
              '[{"id":1,"status":"PRESENT","isPresent":true}]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      final records = await repo.getMyAttendance();
      expect(seenPath, '/api/student/attendance/my');
      expect(records.length, 1);
      expect(records[0].isPresent, true);
    });
  });

  group('AttendanceRepository error handling', () {
    test('403 throws ApiException', () async {
      final client = _clientReturning(403, '{"message":"Not assigned"}');
      final repo = AttendanceRepository(client);
      try {
        await repo.getSessions();
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
        expect(e.message, 'You are not authorized to perform this action.');
      }
    });

    test('409 throws ApiException', () async {
      final client =
          _clientReturning(409, '{"message":"Duplicate session"}');
      final repo = AttendanceRepository(client);
      try {
        await repo.createSession(
          const AttendanceSessionCreateRequest(
              subjectId: 1, sectionId: 1, lecturePeriod: '1st', date: '2026-01-01'),
        );
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 409);
      }
    });
  });

  group('AttendanceRepository.getOverallAttendanceCalculation', () {
    test('sends GET to student/attendance/calculation', () async {
      String? seenPath;
      String? seenAuth;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenAuth = req.headers['Authorization'];
          return http.Response(
              '{"presentCount":5,"totalRecordedCount":8,"percentage":62.5}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      final result = await repo.getOverallAttendanceCalculation();
      expect(seenPath, '/api/student/attendance/calculation');
      expect(seenAuth, 'Bearer token');
      expect(result.presentCount, 5);
      expect(result.totalRecordedCount, 8);
      expect(result.percentage, 62.5);
    });

    test('parses zero-record response with null percentage', () async {
      final client = _clientReturning(200,
          '{"presentCount":0,"totalRecordedCount":0,"percentage":null}');
      final repo = AttendanceRepository(client);
      final result = await repo.getOverallAttendanceCalculation();
      expect(result.presentCount, 0);
      expect(result.totalRecordedCount, 0);
      expect(result.percentage, isNull);
    });

    test('sends startDate and endDate query params only when present', () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"presentCount":5,"totalRecordedCount":8,"percentage":62.5}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.getOverallAttendanceCalculation(
          startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      expect(seenPath, '/api/student/attendance/calculation');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!['endDate'], '2026-01-31');
      expect(seenQuery!.containsKey('studentId'), isFalse);
    });

    test('start-only sends only startDate', () async {
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenQuery = req.url.queryParameters;
          return http.Response('{"presentCount":0,"totalRecordedCount":0,"percentage":null}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.getOverallAttendanceCalculation(startDate: DateTime(2026, 1, 1));
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!.containsKey('endDate'), isFalse);
      expect(seenQuery!.containsKey('studentId'), isFalse);
    });

    test('end-only sends only endDate', () async {
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenQuery = req.url.queryParameters;
          return http.Response('{"presentCount":0,"totalRecordedCount":0,"percentage":null}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.getOverallAttendanceCalculation(endDate: DateTime(2026, 1, 31));
      expect(seenQuery!.containsKey('startDate'), isFalse);
      expect(seenQuery!['endDate'], '2026-01-31');
      expect(seenQuery!.containsKey('studentId'), isFalse);
    });

    test('no dates leaves the query string empty', () async {
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenQuery = req.url.queryParameters;
          return http.Response('{"presentCount":0,"totalRecordedCount":0,"percentage":null}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.getOverallAttendanceCalculation();
      expect(seenQuery, isEmpty);
    });

    test('inverted range is forwarded as-is; backend 400 surfaces as ApiException',
        () async {
      final client = _clientReturning(
          400, '{"message":"startDate must not be after endDate"}');
      final repo = AttendanceRepository(client);
      try {
        await repo.getOverallAttendanceCalculation(
            startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 1, 1));
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, 'startDate must not be after endDate');
      }
    });
  });

  group('AttendanceRepository.getSubjectAttendanceCalculation', () {
    test('sends GET with subject ID in path', () async {
      String? seenPath;
      String? seenAuth;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenAuth = req.headers['Authorization'];
          return http.Response(
              '{"presentCount":3,"totalRecordedCount":4,"percentage":75.0}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      final result = await repo.getSubjectAttendanceCalculation(7);
      expect(seenPath, '/api/student/attendance/calculation/subject/7');
      expect(seenAuth, 'Bearer token');
      expect(result.presentCount, 3);
      expect(result.totalRecordedCount, 4);
      expect(result.percentage, 75.0);
    });

    test('sends subject path with date query params and no studentId', () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"presentCount":3,"totalRecordedCount":4,"percentage":75.0}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.getSubjectAttendanceCalculation(7,
          startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      expect(seenPath, '/api/student/attendance/calculation/subject/7');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!['endDate'], '2026-01-31');
      expect(seenQuery!.containsKey('studentId'), isFalse);
    });
  });

  group('AttendanceRepository calculation error handling', () {
    test('API error is surfaced as ApiException', () async {
      final client =
          _clientReturning(500, '{"message":"Server error"}');
      final repo = AttendanceRepository(client);
      try {
        await repo.getOverallAttendanceCalculation();
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
      }
    });

    test('subject calculation API error is surfaced', () async {
      final client =
          _clientReturning(403, '{"message":"Forbidden"}');
      final repo = AttendanceRepository(client);
      try {
        await repo.getSubjectAttendanceCalculation(3);
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
      }
    });
  });

  group('AttendanceRepository.getSubjectAttendanceSummaries', () {
    test('sends GET to student/attendance/calculation/subjects', () async {
      String? seenPath;
      String? seenAuth;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenAuth = req.headers['Authorization'];
          return http.Response(
              '[{"subjectId":5,"subjectName":"DS","presentCount":8,"totalRecordedCount":10,"percentage":80.0}]',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      final result = await repo.getSubjectAttendanceSummaries();
      expect(seenPath, '/api/student/attendance/calculation/subjects');
      expect(seenAuth, 'Bearer token');
      expect(result.length, 1);
      expect(result[0].subjectName, 'DS');
      expect(result[0].presentCount, 8);
    });

    test('sends subject path with date query params and no studentId',
        () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.getSubjectAttendanceSummaries(
          startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      expect(seenPath, '/api/student/attendance/calculation/subjects');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!['endDate'], '2026-01-31');
      expect(seenQuery!.containsKey('studentId'), isFalse);
    });
  });

  group('AttendanceRepository.getCalendarAttendanceSummary', () {
    test('sends GET to student/attendance/calculation/calendar', () async {
      String? seenPath;
      String? seenAuth;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenAuth = req.headers['Authorization'];
          return http.Response(
              '[{"date":"2026-09-04","presentCount":3,"absentCount":1,"totalRecordedCount":4,"percentage":75.0}]',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      final result = await repo.getCalendarAttendanceSummary();
      expect(seenPath, '/api/student/attendance/calculation/calendar');
      expect(seenAuth, 'Bearer token');
      expect(result.length, 1);
      expect(result[0].date, '2026-09-04');
      expect(result[0].presentCount, 3);
      expect(result[0].absentCount, 1);
    });

    test('sends calendar path with date query params and no studentId',
        () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.getCalendarAttendanceSummary(
          startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      expect(seenPath, '/api/student/attendance/calculation/calendar');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!['endDate'], '2026-01-31');
      expect(seenQuery!.containsKey('studentId'), isFalse);
    });
  });
}
