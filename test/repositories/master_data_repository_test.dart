import 'dart:convert';

import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
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

  group('MasterDataRepository.createDepartment', () {
    test('sends POST to admin/departments with the request body', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(
              '{"id":5,"name":"Computer Engineering","code":"CE","description":"Engg"}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      final department = await repo.createDepartment(const DepartmentRequest(
          name: 'Computer Engineering', code: 'CE', description: 'Engg'));
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/admin/departments');
      expect(jsonDecode(seen.body),
          {'name': 'Computer Engineering', 'code': 'CE', 'description': 'Engg'});
      expect(department.id, 5);
      expect(department.name, 'Computer Engineering');
    });

    test('omits empty description', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response('{"id":1,"name":"CSE","code":"CS"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      await repo.createDepartment(const DepartmentRequest(name: 'CSE', code: 'CS'));
      expect(jsonDecode(seen.body), {'name': 'CSE', 'code': 'CS'});
    });
  });

  group('MasterDataRepository.updateDepartment', () {
    test('sends PUT to admin/departments/{id} and parses the response', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response('{"id":5,"name":"Updated","code":"CE"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      final department =
          await repo.updateDepartment(5, const DepartmentRequest(name: 'Updated', code: 'CE'));
      expect(seen.method, 'PUT');
      expect(seen.url.path, '/api/admin/departments/5');
      expect(jsonDecode(seen.body), {'name': 'Updated', 'code': 'CE'});
      expect(department.name, 'Updated');
    });
  });

  group('MasterDataRepository.deleteDepartment', () {
    test('sends DELETE to admin/departments/{id}', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response('', 204);
        }),
      );
      final repo = MasterDataRepository(client);
      await repo.deleteDepartment(5);
      expect(seen.method, 'DELETE');
      expect(seen.url.path, '/api/admin/departments/5');
    });

    test('propagates a 409 referential conflict', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) => http.Response(
            '{"message":"Cannot delete department. Program(s) exist: CSE"}', 409,
            headers: {'content-type': 'application/json'})),
      );
      final repo = MasterDataRepository(client);
      expect(
        repo.deleteDepartment(5),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message',
                'Cannot delete department. Program(s) exist: CSE')),
      );
    });
  });

  group('MasterDataRepository.createAcademicSession', () {
    test('sends the full numeric payload to admin/academic-sessions',
        () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(
              '{"id":1,"name":"2026-27 Sem 1","code":"S1","semester":"1"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      await repo.createAcademicSession(const AcademicSessionRequest(
        name: '2026-27 Sem 1',
        code: 'S1',
        semester: '1',
        durationHours: 16,
        lecturePeriods: 4,
        credits: 3,
        programId: 2,
      ));
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/admin/academic-sessions');
      expect(jsonDecode(seen.body), {
        'name': '2026-27 Sem 1',
        'code': 'S1',
        'semester': '1',
        'durationHours': 16,
        'lecturePeriods': 4,
        'credits': 3,
        'programId': 2,
      });
    });
  });

  group('MasterDataRepository.createSubject', () {
    test('sends code/name/creditHours/status/department to admin/subjects',
        () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response('{"id":1,"code":"CS301","name":"DBMS"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      final subject = await repo.createSubject(const SubjectRequest(
        code: 'CS301',
        name: 'DBMS',
        creditHours: '3',
        status: 'ACTIVE',
        department: 'Computer Science',
      ));
      expect(seen.url.path, '/api/admin/subjects');
      expect(jsonDecode(seen.body), {
        'code': 'CS301',
        'name': 'DBMS',
        'creditHours': '3',
        'status': 'ACTIVE',
        'department': 'Computer Science',
      });
      expect(subject.name, 'DBMS');
    });
  });

  group('MasterDataRepository.updateProgram', () {
    test('sends PUT to admin/programs/{id} with departmentId', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response('{"id":9,"name":"B.Tech CE","code":"CE"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      await repo.updateProgram(9, const ProgramRequest(
          name: 'B.Tech CE', code: 'CE', duration: '4 years', departmentId: 2));
      expect(seen.method, 'PUT');
      expect(seen.url.path, '/api/admin/programs/9');
      expect(jsonDecode(seen.body), {
        'name': 'B.Tech CE',
        'code': 'CE',
        'duration': '4 years',
        'departmentId': 2,
      });
    });
  });

  group('MasterDataRepository errors', () {
    test('403 maps to ApiException.forbidden', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) => http.Response('{"error":"Forbidden"}', 403,
            headers: {'content-type': 'application/json'})),
      );
      final repo = MasterDataRepository(client);
      expect(
        repo.updateDepartment(1, const DepartmentRequest(name: 'x', code: 'x')),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('non-map 200 create response maps to serverError', () async {
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) => http.Response('[1,2,3]', 200,
            headers: {'content-type': 'application/json'})),
      );
      final repo = MasterDataRepository(client);
      expect(
        repo.createDepartment(const DepartmentRequest(name: 'X', code: 'X')),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}