import 'dart:convert';

import 'package:dagacs_frontend/models/student_management.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/student_management_repository.dart';
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
    tokenProvider: () async => 'admin-token',
    httpClient: _MockClient(
        (req) => http.Response(body, status,
            headers: {'content-type': 'application/json'})),
  );
}

ApiClient _capturingClient(
    void Function(http.Request request) handler) {
  return ApiClient(
    baseUrl: 'http://test.local/api',
    tokenProvider: () async => 'admin-token',
    httpClient: _MockClient((req) {
      handler(req);
      return http.Response(
          '{"id":1,"rollNumber":"2201CE001","name":"Rahul Kumar",'
          '"status":"ACTIVE","programId":1,"programName":"Computer Science",'
          '"batchId":1,"batchName":"B1","sectionId":1,"sectionName":"A"}',
          200,
          headers: {'content-type': 'application/json'});
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentManagementRepository.searchStudents', () {
    test('sends GET to admin/students with default page params and parses the page',
        () async {
      String? seenPath;
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"content":[{"id":1,"rollNumber":"2201CE001",'
              '"name":"Rahul Kumar","status":"ACTIVE"},'
              '{"id":2,"rollNumber":"2201CE002",'
              '"name":"Anjali","status":"INACTIVE"}],'
              '"page":0,"size":20,"totalElements":2,"totalPages":1}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      final page =
          await repo.searchStudents(const StudentSearchQuery());
      expect(seenPath, '/api/admin/students');
      expect(seenQuery!['page'], '0');
      expect(seenQuery!['size'], '20');
      expect(page.content, hasLength(2));
      expect(page.totalElements, 2);
      expect(page.totalPages, 1);
      expect(page.isEmpty, isFalse);
      expect(page.content.first.rollNumber, '2201CE001');
      expect(page.content.first.isActive, isTrue);
      expect(page.content.last.status, 'INACTIVE');
    });

    test('sends every explicitly selected filter as a query parameter',
        () async {
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"content":[],"page":0,"size":20,"totalElements":0,'
              '"totalPages":0}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      await repo.searchStudents(const StudentSearchQuery(
        search: '  rahul  ',
        academicSessionId: 1,
        programId: 2,
        semesterId: 3,
        batchId: 4,
        sectionId: 5,
        status: 'ACTIVE',
        loginStatus: 'ACTIVE',
        page: 1,
        size: 50,
      ));
      expect(seenQuery!['search'], 'rahul');
      expect(seenQuery!['academicSessionId'], '1');
      expect(seenQuery!['programId'], '2');
      expect(seenQuery!['semesterId'], '3');
      expect(seenQuery!['batchId'], '4');
      expect(seenQuery!['sectionId'], '5');
      expect(seenQuery!['status'], 'ACTIVE');
      expect(seenQuery!['loginStatus'], 'ACTIVE');
      expect(seenQuery!['page'], '1');
      expect(seenQuery!['size'], '50');
    });

    test('omits unset filters from the query', () async {
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"content":[],"page":0,"size":20,"totalElements":0,'
              '"totalPages":0}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      await repo.searchStudents(const StudentSearchQuery(page: 2));
      expect(seenQuery!.containsKey('search'), isFalse);
      expect(seenQuery!.containsKey('status'), isFalse);
      expect(seenQuery!.containsKey('academicSessionId'), isFalse);
      expect(seenQuery!['page'], '2');
      expect(seenQuery!['size'], '20');
    });

    test('throws serverError when response is not an object', () async {
      final client = _clientReturning(200, '[]');
      final repo = StudentManagementRepository(client);
      expect(
        repo.searchStudents(const StudentSearchQuery()),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('throws ApiException on 403', () async {
      final client = _clientReturning(403, '{"error":"Forbidden"}');
      final repo = StudentManagementRepository(client);
      expect(
        repo.searchStudents(const StudentSearchQuery()),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('StudentManagementRepository.getFilterOptions', () {
    test('sends GET to admin/students/filter-options and parses the lists',
        () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response(
              '{"academicSessions":[{"id":1,"name":"2026-27"}],'
              '"programs":[{"id":10,"name":"Computer Science"}],'
              '"semesters":[{"id":3,"name":"Sem 1","code":"S1"}],'
              '"batches":[{"id":7,"name":"B1"}],'
              '"sections":[{"id":5,"name":"A"}]}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      final options = await repo.getFilterOptions(academicSessionId: 1);
      expect(seenPath, '/api/admin/students/filter-options');
      expect(options.academicSessions.single.name, '2026-27');
      expect(options.programs.single.displayName, 'Computer Science');
      expect(options.semesters.single.name, 'Sem 1');
      expect(options.batches.single.name, 'B1');
      expect(options.sections.single.id, 5);
    });

    test('sends the selected parent ids to scope the options', () async {
      Map<String, String>? seenQuery;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenQuery = req.url.queryParameters;
          return http.Response(
              '{"academicSessions":[],"programs":[],"semesters":[],'
              '"batches":[],"sections":[]}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      await repo.getFilterOptions(
        academicSessionId: 1,
        programId: 2,
        semesterId: 3,
        batchId: 4,
        sectionId: 5,
      );
      expect(seenQuery!['academicSessionId'], '1');
      expect(seenQuery!['programId'], '2');
      expect(seenQuery!['semesterId'], '3');
      expect(seenQuery!['batchId'], '4');
      expect(seenQuery!['sectionId'], '5');
    });

    test('throws serverError when the response is not an object', () async {
      final client = _clientReturning(200, '[]');
      final repo = StudentManagementRepository(client);
      expect(
        repo.getFilterOptions(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });

  group('StudentManagementRepository.getStudent', () {
    test('sends GET to admin/students/{id} and parses', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response(
              '{"id":3,"rollNumber":"2201CE003","name":"Anjali",'
              '"status":"ACTIVE"}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      final student = await repo.getStudent(3);
      expect(seenPath, '/api/admin/students/3');
      expect(student.name, 'Anjali');
    });

    test('throws 404 when not found', () async {
      final client = _clientReturning(404, '{"message":"Not found"}');
      final repo = StudentManagementRepository(client);
      expect(
        repo.getStudent(99),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('StudentManagementRepository.createStudent', () {
    test('POSTs to admin/students with body and parses result', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = StudentManagementRepository(client);
      const request = StudentManagementRequest(
        rollNumber: '2201CE001',
        name: 'Rahul Kumar',
        gender: 'M',
        status: 'ACTIVE',
        programId: 1,
        batchId: 1,
        sectionId: 1,
      );
      final student = await repo.createStudent(request);
      final bodyMap = body! as Map;
      expect(method, 'POST');
      expect(seenPath, '/api/admin/students');
      expect(bodyMap['rollNumber'], '2201CE001');
      expect(bodyMap['name'], 'Rahul Kumar');
      expect(bodyMap.containsKey('email'), isFalse);
      expect(student.id, 1);
    });

    test('throws 409 on duplicate roll number', () async {
      final client = _clientReturning(409, '{"message":"Duplicate"}');
      final repo = StudentManagementRepository(client);
      const request = StudentManagementRequest(
          rollNumber: 'X', name: 'Y', programId: 1, batchId: 1, sectionId: 1);
      expect(
        repo.createStudent(request),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('StudentManagementRepository.updateStudent', () {
    test('PUTs to admin/students/{id} with body', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = StudentManagementRepository(client);
      const request = StudentManagementRequest(
          rollNumber: '2201CE001',
          name: 'Rahul Kumar',
          programId: 1,
          batchId: 1,
          sectionId: 1);
      final student = await repo.updateStudent(3, request);
      final bodyMap = body! as Map;
      expect(method, 'PUT');
      expect(seenPath, '/api/admin/students/3');
      expect(bodyMap['name'], 'Rahul Kumar');
      expect(student.name, 'Rahul Kumar');
    });
  });

  group('StudentManagementRepository.setStudentStatus', () {
    test('PATCHes status to admin/students/{id}/status', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = StudentManagementRepository(client);
      final student = await repo.setStudentStatus(3, 'INACTIVE');
      final bodyMap = body! as Map;
      expect(method, 'PATCH');
      expect(seenPath, '/api/admin/students/3/status');
      expect(bodyMap['status'], 'INACTIVE');
      expect(student.status, 'ACTIVE');
    });
  });

  group('StudentManagementRepository.provisionLogin', () {
    test('POSTs to admin/students/{id}/login without a password and parses'
        ' the temporary password', () async {
      String? method;
      String? seenPath;
      String? seenBody;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          method = req.method;
          seenPath = req.url.path;
          seenBody = req.body;
          return http.Response(
              '{"id":3,"rollNumber":"2201CE001","name":"Rahul Kumar",'
              '"loginLinked":true,"loginStatus":"ACTIVE",'
              '"mustChangePassword":true,"temporaryPassword":"TempPass#2026"}',
              201,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      final student = await repo.provisionLogin(3);
      expect(method, 'POST');
      expect(seenPath, '/api/admin/students/3/login');
      expect(seenBody, isEmpty);
      expect(student.hasLogin, isTrue);
      expect(student.loginStatus, 'ACTIVE');
      expect(student.mustChangePassword, isTrue);
      expect(student.temporaryPassword, 'TempPass#2026');
    });

    test('throws 400 with the backend message when the student has no email',
        () async {
      final client = _clientReturning(
          400, '{"error":"Unauthorized","message":"The student has no email to link a login to"}');
      final repo = StudentManagementRepository(client);
      expect(
        repo.provisionLogin(4),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message',
                'The student has no email to link a login to')),
      );
    });

    test('throws 409 when the email already owns a login', () async {
      final client =
          _clientReturning(409, '{"message":"Email is already in use by a login account"}');
      final repo = StudentManagementRepository(client);
      expect(
        repo.provisionLogin(3),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('StudentManagementRepository.setLoginStatus', () {
    test('PATCHes status to admin/students/{id}/login/status', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = StudentManagementRepository(client);
      final student = await repo.setLoginStatus(3, 'INACTIVE');
      final bodyMap = body! as Map;
      expect(method, 'PATCH');
      expect(seenPath, '/api/admin/students/3/login/status');
      expect(bodyMap['status'], 'INACTIVE');
      expect(student.status, 'ACTIVE');
    });
  });

  group('StudentManagementRepository.setLoginPassword', () {
    test('PUTs the new password to admin/students/{id}/login/password',
        () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = StudentManagementRepository(client);
      final student = await repo.setLoginPassword(
          3, const StudentLoginPasswordRequest('NewPass#9'));
      final bodyMap = body! as Map;
      expect(method, 'PUT');
      expect(seenPath, '/api/admin/students/3/login/password');
      expect(bodyMap['password'], 'NewPass#9');
      expect(student.id, 1);
    });
  });

  group('StudentManagementRepository.changePassword', () {
    test('PUTs current and new password to student/change-password',
        () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'student-token',
        httpClient: _MockClient((req) {
          method = req.method;
          seenPath = req.url.path;
          body = jsonDecode(req.body);
          return http.Response('{"success":true}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      await repo.changePassword(
        currentPassword: 'Temp#Old2026',
        newPassword: 'BrandNew#2026',
        confirmPassword: 'BrandNew#2026',
      );
      final bodyMap = body! as Map;
      expect(method, 'PUT');
      expect(seenPath, '/api/student/change-password');
      expect(bodyMap['currentPassword'], 'Temp#Old2026');
      expect(bodyMap['newPassword'], 'BrandNew#2026');
      expect(bodyMap['confirmPassword'], 'BrandNew#2026');
    });

    test('accepts successful empty-body 200 without throwing', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'student-token',
        httpClient: _MockClient((req) {
          return http.Response('', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      expect(
        repo.changePassword(
          currentPassword: 'Temp#Old2026',
          newPassword: 'BrandNew#2026',
          confirmPassword: 'BrandNew#2026',
        ),
        completes,
      );
    });

    test('propagates a non-2xx ApiException', () async {
      final client = _clientReturning(400, '{"message":"Current password is incorrect"}');
      final repo = StudentManagementRepository(client);
      expect(
        repo.changePassword(
          currentPassword: 'Wrong#Pass1',
          newPassword: 'BrandNew#2026',
          confirmPassword: 'BrandNew#2026',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message',
                'Current password is incorrect')),
      );
    });

    test('propagates a 403 ApiException', () async {
      final client = _clientReturning(403, '{"message":"Forbidden"}');
      final repo = StudentManagementRepository(client);
      expect(
        repo.changePassword(
          currentPassword: 'Temp#Old2026',
          newPassword: 'BrandNew#2026',
          confirmPassword: 'BrandNew#2026',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('StudentManagementRepository.downloadCredentials', () {
    test('GETs the credential artifact and returns bytes + filename',
        () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response.bytes(
            [1, 2, 3, 4],
            200,
            headers: {
              'content-type':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'content-disposition':
                  'attachment; filename="student_credentials.xlsx"',
            },
          );
        }),
      );
      final repo = StudentManagementRepository(client);
      final payload =
          await repo.downloadCredentials('dl-abcd-1234');
      expect(seenPath, '/api/admin/students/import/credentials/dl-abcd-1234');
      expect(payload.bytes, [1, 2, 3, 4]);
      expect(payload.fileName, 'student_credentials.xlsx');
      expect(payload.contentType, contains('spreadsheetml.sheet'));
    });
  });
}