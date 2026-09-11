import 'dart:convert';

import 'package:dagacs_frontend/models/teacher_management.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/teacher_management_repository.dart';
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

const String _teacherJson =
    '{"id":1,"email":"meera@dagacs.local","fullName":"Meera Iyer",'
    '"phone":"","designation":"Professor","status":"ACTIVE",'
    '"departmentId":1,"departmentName":"Computer Science","isHod":true,'
    '"loginLinked":true,"loginStatus":"ACTIVE"}';

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
    void Function(http.Request request) handler, [String? body]) {
  return ApiClient(
    baseUrl: 'http://test.local/api',
    tokenProvider: () async => 'admin-token',
    httpClient: _MockClient((req) {
      handler(req);
      return http.Response(
          body ?? _teacherJson,
          200,
          headers: {'content-type': 'application/json'});
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TeacherManagementRepository.getTeachers', () {
    test('sends GET to admin/teacher-management/teachers and parses', () async {
      String? seenPath;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seenPath = req.url.path;
          return http.Response(
              '[$_teacherJson,{"id":2,"email":"kiran@dagacs.local",'
              '"fullName":"Kiran Rao","status":"INACTIVE","loginLinked":false}]',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = TeacherManagementRepository(client);
      final teachers = await repo.getTeachers();
      expect(seenPath, '/api/admin/teacher-management/teachers');
      expect(teachers, hasLength(2));
      expect(teachers.first.fullName, 'Meera Iyer');
      expect(teachers.first.isActive, isTrue);
      expect(teachers.first.isHod, isTrue);
      expect(teachers.first.hasLogin, isTrue);
      expect(teachers.first.loginIsActive, isTrue);
      expect(teachers.last.hasLogin, isFalse);
      expect(teachers.last.isActive, isFalse);
    });

    test('throws serverError when response is not a list', () async {
      final repo = TeacherManagementRepository(_clientReturning(200, '{}'));
      expect(
        repo.getTeachers(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('throws ApiException on 403', () async {
      final repo =
          TeacherManagementRepository(_clientReturning(403, '{"error":"x"}'));
      expect(
        repo.getTeachers(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('TeacherManagementRepository.getTeacher', () {
    test('sends GET to .../teachers/{id} and parses', () async {
      String? seenPath;
      final client = _capturingClient((req) => seenPath = req.url.path);
      final repo = TeacherManagementRepository(client);
      final teacher = await repo.getTeacher(1);
      expect(seenPath, '/api/admin/teacher-management/teachers/1');
      expect(teacher.email, 'meera@dagacs.local');
    });

    test('throws 404 when not found', () async {
      final repo = TeacherManagementRepository(
          _clientReturning(404, '{"message":"Not found"}'));
      expect(
        repo.getTeacher(99),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('TeacherManagementRepository.createTeacher', () {
    test('POSTs payload with password and omits empty fields', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = TeacherManagementRepository(client);
      const request = TeacherCreateRequest(
        email: 'new@dagacs.local',
        fullName: 'New Teacher',
        password: 'Pass1234',
        departmentId: 2,
        status: 'ACTIVE',
      );
      final teacher = await repo.createTeacher(request);
      final bodyMap = body! as Map;
      expect(method, 'POST');
      expect(seenPath, '/api/admin/teacher-management/teachers');
      expect(bodyMap['email'], 'new@dagacs.local');
      expect(bodyMap['fullName'], 'New Teacher');
      expect(bodyMap['password'], 'Pass1234');
      expect(bodyMap['departmentId'], 2);
      expect(bodyMap['status'], 'ACTIVE');
      expect(bodyMap.containsKey('phone'), isFalse);
      expect(teacher.id, 1);
    });

    test('throws 409 on email collision', () async {
      final repo = TeacherManagementRepository(
          _clientReturning(409, '{"message":"Duplicate"}'));
      const request = TeacherCreateRequest(
          email: 'dup@dagacs.local',
          fullName: 'Dup',
          password: 'Pass1234');
      expect(
        repo.createTeacher(request),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('throws 400 on weak password', () async {
      final repo = TeacherManagementRepository(
          _clientReturning(400, '{"message":"Password too short"}'));
      const request = TeacherCreateRequest(
          email: 'weak@dagacs.local',
          fullName: 'Weak',
          password: 'short');
      expect(
        repo.createTeacher(request),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('TeacherManagementRepository.updateTeacher', () {
    test('PUTs only non-empty editable fields', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = TeacherManagementRepository(client);
      const request = TeacherUpdateRequest(
          fullName: 'Meera Iyer', designation: 'Assoc Professor', departmentId: 3);
      await repo.updateTeacher(1, request);
      final bodyMap = body! as Map;
      expect(method, 'PUT');
      expect(seenPath, '/api/admin/teacher-management/teachers/1');
      expect(bodyMap['fullName'], 'Meera Iyer');
      expect(bodyMap['designation'], 'Assoc Professor');
      expect(bodyMap['departmentId'], 3);
      expect(bodyMap.containsKey('email'), isFalse);
      expect(bodyMap.containsKey('password'), isFalse);
    });
  });

  group('TeacherManagementRepository.setTeacherStatus', () {
    test('PATCHes status to .../teachers/{id}/status', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = TeacherManagementRepository(client);
      await repo.setTeacherStatus(1, 'INACTIVE');
      expect(method, 'PATCH');
      expect(seenPath, '/api/admin/teacher-management/teachers/1/status');
      expect((body! as Map)['status'], 'INACTIVE');
    });
  });

  group('TeacherManagementRepository.provisionLogin', () {
    test('POSTs password to .../teachers/{id}/login', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = TeacherManagementRepository(client);
      await repo.provisionLogin(1, const TeacherLoginPasswordRequest('Pass1234'));
      expect(method, 'POST');
      expect(seenPath, '/api/admin/teacher-management/teachers/1/login');
      expect((body! as Map)['password'], 'Pass1234');
    });
  });

  group('TeacherManagementRepository.setLoginPassword', () {
    test('PUTs password to .../teachers/{id}/login/password', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = TeacherManagementRepository(client);
      await repo
          .setLoginPassword(1, const TeacherLoginPasswordRequest('NewPass12'));
      expect(method, 'PUT');
      expect(seenPath,
          '/api/admin/teacher-management/teachers/1/login/password');
      expect((body! as Map)['password'], 'NewPass12');
    });
  });

  group('TeacherManagementRepository.setLoginStatus', () {
    test('PATCHes login status to .../teachers/{id}/login/status', () async {
      String? method;
      String? seenPath;
      Object? body;
      final client = _capturingClient((req) {
        method = req.method;
        seenPath = req.url.path;
        body = jsonDecode(req.body);
      });
      final repo = TeacherManagementRepository(client);
      await repo.setLoginStatus(1, 'INACTIVE');
      expect(method, 'PATCH');
      expect(seenPath,
          '/api/admin/teacher-management/teachers/1/login/status');
      expect((body! as Map)['status'], 'INACTIVE');
    });
  });

  group('TeacherManagementRepository.designateHod', () {
    test('PATCHes frozen /admin/teachers/{id}/hod and parses HodIdentity',
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
              '{"email":"meera@dagacs.local","teacherName":"Meera Iyer",'
              '"hod":true,"departmentName":"Computer Science",'
              '"departmentCode":"CSE"}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = TeacherManagementRepository(client);
      final hod = await repo.designateHod(1,
          const TeacherHodDesignationRequest(designated: true, departmentId: 2));
      expect(method, 'PATCH');
      expect(seenPath, '/api/admin/teachers/1/hod');
      expect((body! as Map)['designated'], isTrue);
      expect((body! as Map)['departmentId'], 2);
      expect(hod.hod, isTrue);
      expect(hod.departmentName, 'Computer Science');
    });
  });
}