import 'dart:convert';

import 'package:dagacs_frontend/models/hod_audit_log_entry.dart';
import 'package:dagacs_frontend/models/hod_dashboard.dart';
import 'package:dagacs_frontend/models/hod_low_attendance.dart';
import 'package:dagacs_frontend/models/hod_rollup.dart';
import 'package:dagacs_frontend/models/hod_section_attendance.dart';
import 'package:dagacs_frontend/models/hod_student_attendance.dart';
import 'package:dagacs_frontend/models/hod_subject_attendance.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/hod_repository.dart';
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

  group('HodDashboard.fromJson', () {
    test('parses all fields', () {
      final d = HodDashboard.fromJson({
        'departmentName': 'Computer Engineering',
        'departmentCode': 'CE',
        'programCount': 2,
        'batchCount': 1,
        'sectionCount': 3,
        'studentCount': 60,
        'totalRecordedCount': 500,
        'presentCount': 400,
        'overallPercentage': 80.0,
      });
      expect(d.departmentName, 'Computer Engineering');
      expect(d.departmentCode, 'CE');
      expect(d.programCount, 2);
      expect(d.batchCount, 1);
      expect(d.sectionCount, 3);
      expect(d.studentCount, 60);
      expect(d.totalRecordedCount, 500);
      expect(d.presentCount, 400);
      expect(d.overallPercentage, 80.0);
    });

    test('null percentage stays null (never 0)', () {
      final d = HodDashboard.fromJson({
        'departmentName': 'CE',
        'departmentCode': 'CE',
        'programCount': 0,
        'batchCount': 0,
        'sectionCount': 0,
        'studentCount': 0,
        'totalRecordedCount': 0,
        'presentCount': 0,
        'overallPercentage': null,
      });
      expect(d.overallPercentage, isNull);
    });

    test('missing keys default safely', () {
      final d = HodDashboard.fromJson({'departmentName': 'CE'});
      expect(d.departmentCode, '');
      expect(d.programCount, 0);
      expect(d.overallPercentage, isNull);
    });
  });

  group('HodSectionAttendance.fromJson', () {
    test('parses all fields', () {
      final s = HodSectionAttendance.fromJson({
        'sectionName': 'A',
        'sectionCode': 'CE-A',
        'studentCount': 30,
        'presentCount': 20,
        'totalRecordedCount': 25,
        'percentage': 80.0,
      });
      expect(s.sectionName, 'A');
      expect(s.sectionCode, 'CE-A');
      expect(s.studentCount, 30);
      expect(s.presentCount, 20);
      expect(s.totalRecordedCount, 25);
      expect(s.percentage, 80.0);
    });

    test('absent percentage treated as no data', () {
      final s = HodSectionAttendance.fromJson({
        'sectionName': 'B',
        'sectionCode': 'CE-B',
        'studentCount': 30,
        'presentCount': 0,
        'totalRecordedCount': 0,
      });
      expect(s.percentage, isNull);
    });
  });

  group('HodSubjectAttendance.fromJson', () {
    test('parses all fields', () {
      final s = HodSubjectAttendance.fromJson({
        'subjectCode': 'DS',
        'subjectName': 'Database Systems',
        'presentCount': 10,
        'totalRecordedCount': 12,
        'percentage': 83.33,
      });
      expect(s.subjectCode, 'DS');
      expect(s.subjectName, 'Database Systems');
      expect(s.presentCount, 10);
      expect(s.totalRecordedCount, 12);
      expect(s.percentage, 83.33);
    });
  });

  group('HodStudentAttendance.fromJson', () {
    test('parses all fields', () {
      final s = HodStudentAttendance.fromJson({
        'rollNumber': 'R1',
        'studentName': 'Alice',
        'sectionName': 'A',
        'presentCount': 8,
        'totalRecordedCount': 10,
        'percentage': 80.0,
      });
      expect(s.rollNumber, 'R1');
      expect(s.studentName, 'Alice');
      expect(s.sectionName, 'A');
      expect(s.presentCount, 8);
      expect(s.totalRecordedCount, 10);
      expect(s.percentage, 80.0);
    });

    test('zero-record student has null percentage', () {
      final s = HodStudentAttendance.fromJson({
        'rollNumber': 'R2',
        'studentName': 'Bob',
        'sectionName': 'B',
        'presentCount': 0,
        'totalRecordedCount': 0,
        'percentage': null,
      });
      expect(s.percentage, isNull);
    });
  });

  group('HodLowAttendance.fromJson', () {
    test('parses all fields', () {
      final s = HodLowAttendance.fromJson({
        'rollNumber': 'R9',
        'studentName': 'Carol',
        'sectionName': 'A',
        'presentCount': 5,
        'totalRecordedCount': 10,
        'percentage': 50.0,
      });
      expect(s.rollNumber, 'R9');
      expect(s.studentName, 'Carol');
      expect(s.sectionName, 'A');
      expect(s.percentage, 50.0);
    });
  });

  group('HodRollup.fromJson', () {
    test('parses a monthly period', () {
      final r = HodRollup.fromJson({
        'period': '2026-01',
        'presentCount': 100,
        'totalRecordedCount': 130,
        'percentage': 76.92,
      });
      expect(r.period, '2026-01');
      expect(r.presentCount, 100);
      expect(r.totalRecordedCount, 130);
      expect(r.percentage, 76.92);
    });

    test('parses a quarterly period with null percentage', () {
      final r = HodRollup.fromJson({
        'period': '2026-Q1',
        'presentCount': 0,
        'totalRecordedCount': 0,
        'percentage': null,
      });
      expect(r.period, '2026-Q1');
      expect(r.percentage, isNull);
    });
  });

  group('HodAuditLogEntry.fromJson', () {
    test('parses a full correction entry', () {
      final e = HodAuditLogEntry.fromJson({
        'studentName': 'Alice',
        'rollNo': 'R1',
        'subjectName': 'Database Systems',
        'sectionName': 'A',
        'date': '2026-09-04',
        'previousStatus': 'ABSENT',
        'newStatus': 'PRESENT',
        'updatedBy': 'Teacher T',
        'updatedAt': '2026-09-05T10:15:00',
        'reason': 'Marked by mistake',
      });
      expect(e.studentName, 'Alice');
      expect(e.rollNo, 'R1');
      expect(e.subjectName, 'Database Systems');
      expect(e.sectionName, 'A');
      expect(e.date, '2026-09-04');
      expect(e.previousStatus, 'ABSENT');
      expect(e.newStatus, 'PRESENT');
      expect(e.updatedBy, 'Teacher T');
      expect(e.updatedAt, '2026-09-05T10:15:00');
      expect(e.reason, 'Marked by mistake');
    });

    test('omitted nullable fields stay null', () {
      final e = HodAuditLogEntry.fromJson({'studentName': 'Alice'});
      expect(e.rollNo, isNull);
      expect(e.reason, isNull);
      expect(e.updatedAt, isNull);
    });
  });

  group('HodRepository', () {
    test('getDashboard hits /hod/dashboard with dates only when present',
        () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"departmentName":"CE","departmentCode":"CE","programCount":2,'
              '"batchCount":1,"sectionCount":3,"studentCount":60,'
              '"totalRecordedCount":500,"presentCount":400,"overallPercentage":80.0}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = HodRepository(client);
      await repo.getDashboard(
          startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      expect(seenPath, '/api/hod/dashboard');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!['endDate'], '2026-01-31');
    });

    test('getDashboard without dates sends no query params', () async {
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"departmentName":"CE","departmentCode":"CE","programCount":0,'
              '"batchCount":0,"sectionCount":0,"studentCount":0,'
              '"totalRecordedCount":0,"presentCount":0,"overallPercentage":null}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = HodRepository(client);
      final d = await repo.getDashboard();
      expect(seenQuery, isEmpty);
      expect(d.overallPercentage, isNull);
    });

    test('sections/subjects/students/low/audit hit the correct paths', () async {
      final seen = <String>[];
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seen.add(req.url.path);
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = HodRepository(client);
      await repo.getSections();
      await repo.getSubjects();
      await repo.getStudents();
      await repo.getLowAttendance();
      await repo.getAuditLogs();
      expect(seen, [
        '/api/hod/sections',
        '/api/hod/subjects',
        '/api/hod/students',
        '/api/hod/low-attendance',
        '/api/hod/audit-logs',
      ]);
    });

    test('getRollups sends type=monthly and date params on the same query',
        () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response(
              '[{"period":"2026-01","presentCount":100,"totalRecordedCount":130,'
              '"percentage":76.92}]',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = HodRepository(client);
      final rollups = await repo.getRollups(
          type: 'monthly',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 2, 1));
      expect(seenPath, '/api/hod/rollups');
      expect(seenQuery!['type'], 'monthly');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!['endDate'], '2026-02-01');
      expect(rollups.length, 1);
      expect(rollups[0].period, '2026-01');
    });

    test('getRollups supports quarterly', () async {
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenQuery = req.url.queryParameters;
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = HodRepository(client);
      await repo.getRollups(type: 'quarterly');
      expect(seenQuery!['type'], 'quarterly');
    });

    test('getRollups rejects anything other than monthly/quarterly', () async {
      final repo = HodRepository(ApiClient(
        baseUrl: 'http://test.local/api',
      ));
      expect(
        () => repo.getRollups(type: 'semester'),
        throwsArgumentError,
      );
    });

    test('403 surfaces as ApiException on list endpoints', () async {
      final client = _clientReturning(
          403, '{"message":"HOD access required"}');
      final repo = HodRepository(client);
      try {
        await repo.getStudents();
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
        expect(e.message, 'HOD access required');
      }
    });

    test('non-list response is a server error', () async {
      final client =
          _clientReturning(200, '{"unexpected":"shape"}');
      final repo = HodRepository(client);
      try {
        await repo.getSections();
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
      }
    });

    test('requests carry the Bearer token', () async {
      String? seenAuth;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'hod-token',
        httpClient: _MockClient((req) {
          seenAuth = req.headers['Authorization'];
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = HodRepository(client);
      await repo.getLowAttendance();
      expect(seenAuth, 'Bearer hod-token');
    });
  });
}