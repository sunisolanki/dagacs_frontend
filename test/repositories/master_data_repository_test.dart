import 'dart:convert';

import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/models/subject_offering.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
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
    test('sends the full payload to admin/academic-sessions',
        () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(
              '{"id":1,"name":"2026-27 Sem 1","code":"S1"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      await repo.createAcademicSession(const AcademicSessionRequest(
        name: '2026-27 Sem 1',
        code: 'S1',
        programId: 2,
      ));
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/admin/academic-sessions');
      expect(jsonDecode(seen.body), {
        'name': '2026-27 Sem 1',
        'code': 'S1',
        'programId': 2,
      });
    });
  });

  group('MasterDataRepository.createSubject', () {
    test('sends code/name/creditHours/status/departmentId to admin/subjects',
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
        departmentId: 1,
        status: 'ACTIVE',
      ));
      expect(seen.url.path, '/api/admin/subjects');
      expect(jsonDecode(seen.body), {
        'code': 'CS301',
        'name': 'DBMS',
        'creditHours': '3',
        'status': 'ACTIVE',
        'departmentId': 1,
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

  group('MasterDataRepository.createSubjectOffering', () {
    test('sends only subjectId/semesterId to admin/subject-offerings',
        () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(
              '{"id":7,"subjectId":4,"semesterId":5,'
              '"subject":{"id":4,"code":"CS301","name":"DBMS"},'
              '"semester":{"id":5,"name":"Semester 5","code":"SEM5",'
              '"academicSessionId":3,"academicSession":'
              '{"id":3,"name":"2026-27","code":"2026-27"}}}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      final offering = await repo.createSubjectOffering(
          const SubjectOfferingRequest(subjectId: 4, semesterId: 5));
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/admin/subject-offerings');
      expect(jsonDecode(seen.body), {'subjectId': 4, 'semesterId': 5});
      expect(offering.id, 7);
      expect(offering.subject?.code, 'CS301');
      expect(offering.semester?.name, 'Semester 5');
      expect(offering.semester?.academicSession?.name, '2026-27');
    });
  });

  group('MasterDataRepository.createTeacherAssignment', () {
    test('sends exactly teacherId/subjectOfferingId/sectionId to '
        'admin/teacher-assignments', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(
              '{"id":7,"teacherId":2,"teacherName":"Dr A Sharma",'
              '"subjectOfferingId":5,"subjectId":4,"subjectCode":"CS301",'
              '"subjectName":"DBMS","semesterId":3,"semesterName":"Semester 3",'
              '"sessionId":1,"sessionName":"2026-27","programId":8,'
              '"programName":"B.Tech CSE","departmentId":2,'
              '"departmentName":"Computer Science","sectionId":9,'
              '"sectionCode":"A","sectionName":"Section A","batchId":6,'
              '"batchCode":"B1"}',
              201,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      final assignment = await repo.createTeacherAssignment(
          const TeacherAssignmentRequest(
              teacherId: 2, subjectOfferingId: 5, sectionId: 9));
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/admin/teacher-assignments');
      expect(jsonDecode(seen.body),
          {'teacherId': 2, 'subjectOfferingId': 5, 'sectionId': 9});
      expect(assignment.id, 7);
      expect(assignment.teacherName, 'Dr A Sharma');
      expect(assignment.subjectCode, 'CS301');
      expect(assignment.sectionName, 'Section A');
      expect(assignment.batchCode, 'B1');
    });
  });

  group('MasterDataRepository.updateTeacherAssignment', () {
    test('sends PUT to admin/teacher-assignments/{id}', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(
              '{"id":7,"teacherId":2,"subjectOfferingId":5,"sectionId":9}',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      await repo.updateTeacherAssignment(
          7,
          const TeacherAssignmentRequest(
              teacherId: 2, subjectOfferingId: 5, sectionId: 9));
      expect(seen.method, 'PUT');
      expect(seen.url.path, '/api/admin/teacher-assignments/7');
      expect(jsonDecode(seen.body),
          {'teacherId': 2, 'subjectOfferingId': 5, 'sectionId': 9});
    });
  });

  group('MasterDataRepository.deleteTeacherAssignment', () {
    test('sends DELETE to admin/teacher-assignments/{id}', () async {
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
      await repo.deleteTeacherAssignment(7);
      expect(seen.method, 'DELETE');
      expect(seen.url.path, '/api/admin/teacher-assignments/7');
    });
  });

  group('MasterDataRepository.getTeacherAssignments', () {
    test('GETs admin/teacher-assignments and parses the full list', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(
              '[{"id":7,"teacherId":2,"teacherName":"Dr A Sharma",'
              '"teacherEmail":"a@college.edu",'
              '"subjectOfferingId":5,"subjectId":4,"subjectCode":"CS301",'
              '"subjectName":"DBMS","semesterId":3,"semesterName":"Semester 3",'
              '"sessionId":1,"sessionName":"2026-27","programId":8,'
              '"programName":"B.Tech CSE","departmentId":2,'
              '"departmentName":"Computer Science","sectionId":9,'
              '"sectionCode":"A","sectionName":"Section A","batchId":6,'
              '"batchCode":"B1","createdAt":"2026-09-01T10:00:00Z",'
              '"updatedAt":"2026-09-01T10:00:00Z"}]',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      final list = await repo.getTeacherAssignments();
      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/admin/teacher-assignments');
      expect(list, hasLength(1));
      expect(list.single.teacherEmail, 'a@college.edu');
    });
  });

  group('MasterDataRepository.getTeachers', () {
    test('GETs admin/teachers and parses Teacher rows', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test.local/api',
        tokenProvider: () async => 'admin-token',
        httpClient: _MockClient((req) {
          seen = req;
          return http.Response(
              '[{"id":2,"email":"a@college.edu","fullName":"Dr A Sharma",'
              '"designation":"Professor","status":"ACTIVE",'
              '"departmentId":2,"departmentName":"Computer Science"}]',
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final repo = MasterDataRepository(client);
      final list = await repo.getTeachers();
      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/admin/teachers');
      expect(list, hasLength(1));
      expect(list.single.fullName, 'Dr A Sharma');
      expect(list.single.designation, 'Professor');
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