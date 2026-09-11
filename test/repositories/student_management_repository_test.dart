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

  group('StudentManagementRepository.getStudents', () {
    test('sends GET to admin/students and parses the list', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response(
              '[{"id":1,"rollNumber":"2201CE001","name":"Rahul Kumar",'
              '"status":"ACTIVE"},{"id":2,"rollNumber":"2201CE002",'
              '"name":"Anjali","status":"INACTIVE"}]',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      final students = await repo.getStudents();
      expect(seenPath, '/api/admin/students');
      expect(students, hasLength(2));
      expect(students.first.rollNumber, '2201CE001');
      expect(students.first.isActive, isTrue);
      expect(students.last.status, 'INACTIVE');
    });

    test('throws serverError when response is not a list', () async {
      final client = _clientReturning(200, '{"id":1}');
      final repo = StudentManagementRepository(client);
      expect(
        repo.getStudents(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('throws ApiException on 403', () async {
      final client = _clientReturning(403, '{"error":"Forbidden"}');
      final repo = StudentManagementRepository(client);
      expect(
        repo.getStudents(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
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
    test('POSTs the write-only password to admin/students/{id}/login',
        () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          method = req.method;
          seenPath = req.url.path;
          body = jsonDecode(req.body);
          return http.Response(
              '{"id":3,"rollNumber":"2201CE001","name":"Rahul Kumar",'
              '"loginLinked":true,"loginStatus":"ACTIVE"}',
              201,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = StudentManagementRepository(client);
      final student = await repo.provisionLogin(
          3, const StudentLoginPasswordRequest('StuPass#1'));
      final bodyMap = body! as Map;
      expect(method, 'POST');
      expect(seenPath, '/api/admin/students/3/login');
      expect(bodyMap['password'], 'StuPass#1');
      expect(student.hasLogin, isTrue);
      expect(student.loginStatus, 'ACTIVE');
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
}