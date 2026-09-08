import 'dart:typed_data';

import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
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
      Stream.value(resp.bodyBytes),
      resp.statusCode,
      headers: resp.headers,
    );
  }
}

ApiClient _clientReturning(int status, [String body = '']) {
  return ApiClient(
    baseUrl: 'http://test.local/api',
    tokenProvider: () async => 'token',
    httpClient: _MockClient((req) =>
        http.Response(body, status, headers: {'content-type': 'application/json'})),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportRepository.getDailyLecture', () {
    test('sends paginated GET without dates', () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"content":[],"number":0,"totalPages":0}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = ReportRepository(client);
      await repo.getDailyLecture();
      expect(seenPath, '/api/hod/reports/daily-lecture');
      expect(seenQuery!['page'], '0');
      expect(seenQuery!['size'], '20');
      expect(seenQuery!.containsKey('startDate'), isFalse);
      expect(seenQuery!.containsKey('endDate'), isFalse);
      expect(seenQuery!.containsKey('departmentId'), isFalse);
    });

    test('sends inclusive dates only when provided and parses rows', () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"content":[{"date":"2026-01-10","lecturePeriod":"LP1",'
              '"subjectCode":"S1","subjectName":"DS","sectionCode":"A",'
              '"sectionName":"A","presentCount":2,"totalRecordedCount":3,'
              '"percentage":66.66666}],"number":0,"totalPages":1}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = ReportRepository(client);
      final page = await repo.getDailyLecture(
        page: 2,
        size: 20,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );
      expect(seenPath, '/api/hod/reports/daily-lecture');
      expect(seenQuery!['page'], '2');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!['endDate'], '2026-01-31');
      expect(page.items.single.subjectCode, 'S1');
      expect(page.items.single.percentage, 66.66666);
    });
  });

  group('ReportRepository.getCoverage', () {
    test('sends GET to /api/hod/coverage', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response(
              '{"content":[{"subjectCode":"S1","subjectName":"DS",'
              '"sectionCode":"A","sectionName":"A",'
              '"recordedDateCount":2,"sessionCount":2}],'
              '"number":0,"totalPages":1}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = ReportRepository(client);
      final page = await repo.getCoverage();
      expect(seenPath, '/api/hod/coverage');
      expect(page.items.single.recordedDateCount, 2);
    });
  });

  group('ReportRepository.getTeacherReport', () {
    test('sends GET to teacher/attendance/report and parses own rows', () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response(
              '[{"subjectId":1,"subjectCode":"DS","subjectName":"Data Structures",'
              '"sectionId":2,"sectionCode":"A","sectionName":"Section A",'
              '"presentCount":5,"totalRecordedCount":8,"percentage":62.5}]',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = ReportRepository(client);
      final rows = await repo.getTeacherReport(
          startDate: DateTime(2026, 1, 1));
      expect(seenPath, '/api/teacher/attendance/report');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!.containsKey('endDate'), isFalse);
      expect(seenQuery!.containsKey('teacherId'), isFalse);
      expect(seenQuery!.containsKey('studentId'), isFalse);
      expect(rows.single.presentCount, 5);
    });
  });

  group('ReportRepository HOD export', () {
    test('Excel export hits /export.xlsx and parses backend headers', () async {
      String? seenPath;
      String? seenAuth;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenAuth = req.headers['Authorization'];
          return http.Response.bytes(
            Uint8List.fromList(const [0x50, 0x4b, 0x03, 0x04]),
            200,
            headers: {
              'content-disposition':
                  'attachment; filename="dagacs_hod_daily-lecture_all.xlsx"',
              'content-type':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            },
          );
        }),
      );
      final repo = ReportRepository(client);
      final payload = await repo.exportHodReport('daily-lecture', 'xlsx');
      expect(seenPath, '/api/hod/reports/daily-lecture/export.xlsx');
      expect(seenAuth, 'Bearer token');
      expect(payload.fileName, 'dagacs_hod_daily-lecture_all.xlsx');
      expect(payload.contentType,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      expect(payload.bytes, [0x50, 0x4b, 0x03, 0x04]);
    });

    test('PDF export hits /export.pdf with date query', () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response.bytes(
            Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
            200,
            headers: {
              'content-disposition':
                  'attachment; filename="dagacs_hod_daily-lecture_2026-01-01_to_2026-01-31.pdf"',
              'content-type': 'application/pdf'
            },
          );
        }),
      );
      final repo = ReportRepository(client);
      final payload = await repo.exportHodReport('daily-lecture', 'pdf',
          startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      expect(seenPath, '/api/hod/reports/daily-lecture/export.pdf');
      expect(seenQuery!['startDate'], '2026-01-01');
      expect(seenQuery!['endDate'], '2026-01-31');
      expect(payload.fileName,
          'dagacs_hod_daily-lecture_2026-01-01_to_2026-01-31.pdf');
      expect(payload.bytes, [0x25, 0x50, 0x44, 0x46]);
    });

    test('falls back to a derived file name when header is missing', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient(
            (req) => http.Response.bytes(Uint8List.fromList([1]), 200)),
      );
      final repo = ReportRepository(client);
      final payload = await repo.exportHodReport('coverage', 'xlsx');
      expect(payload.fileName, 'dagacs_hod_coverage_all.xlsx');
    });

    test('semester 400 from backend surfaces as ApiException with message',
        () async {
      final client = _clientReturning(
          400, '{"message":"Unsupported report type for export: semester"}');
      final repo = ReportRepository(client);
      try {
        await repo.exportHodReport('semester', 'xlsx');
        fail('expected ApiException 400');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, 'Unsupported report type for export: semester');
      }
    });

    test('403 surfaces as forbidden', () async {
      final client = _clientReturning(403, '{"message":"Forbidden"}');
      final repo = ReportRepository(client);
      try {
        await repo.exportHodReport('daily-lecture', 'xlsx');
        fail('expected ApiException 403');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
      }
    });
  });

  group('ReportRepository teacher export', () {
    test('Excel export hits /export.xlsx under teacher path', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response.bytes(
            Uint8List.fromList(const [0x50, 0x4b]),
            200,
            headers: {
              'content-disposition':
                  'attachment; filename="dagacs_teacher_subject_wise_all.xlsx"',
              'content-type':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            },
          );
        }),
      );
      final repo = ReportRepository(client);
      final payload = await repo.exportTeacherReport('xlsx');
      expect(seenPath, '/api/teacher/attendance/report/export.xlsx');
      expect(payload.fileName, 'dagacs_teacher_subject_wise_all.xlsx');
    });

    test('PDF export hits /export.pdf and never sends teacherId', () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response.bytes(
            Uint8List.fromList(const [0x25, 0x50]),
            200,
            headers: {
              'content-disposition':
                  'attachment; filename="dagacs_teacher_subject_wise_all.pdf"',
              'content-type': 'application/pdf'
            },
          );
        }),
      );
      final repo = ReportRepository(client);
      await repo.exportTeacherReport('pdf');
      expect(seenPath, '/api/teacher/attendance/report/export.pdf');
      expect(seenQuery!.containsKey('teacherId'), isFalse);
      expect(seenQuery!.containsKey('studentId'), isFalse);
      expect(seenQuery!.containsKey('departmentId'), isFalse);
      expect(seenQuery!.containsKey('sectionId'), isFalse);
    });
  });

  group('ReportRepository error handling', () {
    test('network failure maps to ApiException.network', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'token',
        httpClient: _MockClient((req) {
          throw Exception('connection refused');
        }),
      );
      final repo = ReportRepository(client);
      try {
        await repo.getTeacherReport();
        fail('expected ApiException.network');
      } on ApiException catch (e) {
        expect(e.statusCode, -1);
      }
    });
  });
}