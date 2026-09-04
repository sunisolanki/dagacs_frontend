import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/models/batch.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/section.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies Dart model deserialization against the ACTUAL backend DTO JSON
/// shape (Jackson `non_null`). Only fields defined by the backend are used.
void main() {
  group('AuthResponse', () {
    test('parses login response fields', () {
      final auth = AuthResponse.fromJson({
        'token': 'jwt-value',
        'email': 'admin@dagacs.local',
        'fullName': 'Admin User',
        'role': 'ADMIN',
      });
      expect(auth.token, 'jwt-value');
      expect(auth.email, 'admin@dagacs.local');
      expect(auth.fullName, 'Admin User');
      expect(auth.role, 'ADMIN');
    });
  });

  group('Department', () {
    test('parses full DTO', () {
      final d = Department.fromJson({
        'id': 1,
        'name': 'Computer Science',
        'code': 'CS',
        'description': 'Dept desc',
        'createdBy': 'SYSTEM',
        'createdAt': '2026-09-03T10:00:00',
        'updatedAt': '2026-09-03T10:00:00',
      });
      expect(d.id, 1);
      expect(d.name, 'Computer Science');
      expect(d.code, 'CS');
      expect(d.description, 'Dept desc');
      expect(d.createdBy, 'SYSTEM');
      expect(d.createdAt, '2026-09-03T10:00:00');
    });

    test('parses without optional fields', () {
      final d = Department.fromJson({'id': 2, 'name': 'ECE', 'code': 'EC'});
      expect(d.id, 2);
      expect(d.name, 'ECE');
      expect(d.description, isNull);
    });
  });

  group('Program', () {
    test('parses with nested department', () {
      final p = Program.fromJson({
        'id': 1,
        'name': 'M.Tech CSE',
        'code': 'MTCSE',
        'duration': '2 years',
        'description': 'desc',
        'department': {'id': 1, 'name': 'Computer Science', 'code': 'CS'},
        'departmentId': 1,
      });
      expect(p.id, 1);
      expect(p.name, 'M.Tech CSE');
      expect(p.code, 'MTCSE');
      expect(p.department?.name, 'Computer Science');
      expect(p.departmentId, 1);
    });

    test('parses nested program without department (as in session list)', () {
      final p = Program.fromJson({'id': 5, 'name': 'B.Tech', 'code': 'BT'});
      expect(p.department, isNull);
      expect(p.name, 'B.Tech');
    });
  });

  group('AcademicSession', () {
    test('parses with programId and nested program', () {
      final s = AcademicSession.fromJson({
        'id': 1,
        'name': '2026-27',
        'code': '2026-27',
        'semester': 'Semester 1',
        'durationHours': 40,
        'lecturePeriods': 30,
        'credits': 20,
        'description': 'desc',
        'programId': 1,
        'program': {'id': 1, 'name': 'M.Tech CSE', 'code': 'MTCSE'},
      });
      expect(s.id, 1);
      expect(s.programId, 1);
      expect(s.program?.name, 'M.Tech CSE');
      expect(s.durationHours, 40);
    });
  });

  group('Semester', () {
    test('parses with academicSessionId and nested session', () {
      final s = Semester.fromJson({
        'id': 1,
        'name': 'Semester 1',
        'code': 'SEM1',
        'year': 2026,
        'academicSessionId': 3,
        'academicSession': {'id': 3, 'name': '2026-27', 'code': '2026-27'},
      });
      expect(s.academicSessionId, 3);
      expect(s.academicSession?.name, '2026-27');
      expect(s.name, 'Semester 1');
    });
  });

  group('Batch', () {
    test('parses with program name and nested session', () {
      final b = Batch.fromJson({
        'id': 1,
        'batchCode': 'B-2026-A',
        'name': 'Batch A',
        'year': 2026,
        'academicSessionId': 3,
        'academicSession': {'id': 3, 'name': '2026-27', 'code': '2026-27'},
        'program': 'M.Tech CSE',
        'maxCapacity': 60,
      });
      expect(b.batchCode, 'B-2026-A');
      expect(b.program, 'M.Tech CSE');
      expect(b.academicSession?.name, '2026-27');
      expect(b.maxCapacity, 60);
    });
  });

  group('Section', () {
    test('parses with nested batch', () {
      final s = Section.fromJson({
        'id': 1,
        'sectionCode': 'SEC-A',
        'name': 'A',
        'maxCapacity': 30,
        'batchId': 2,
        'batch': {'id': 2, 'batchCode': 'B-2026-A', 'name': 'Batch A'},
      });
      expect(s.sectionCode, 'SEC-A');
      expect(s.batchId, 2);
      expect(s.batch?.name, 'Batch A');
    });
  });

  group('Subject', () {
    test('parses flat DTO with string department (no parent FK)', () {
      final s = Subject.fromJson({
        'id': 1,
        'code': 'CS101',
        'name': 'Data Structures',
        'description': 'desc',
        'creditHours': '3',
        'department': 'Computer Science',
        'status': 'ACTIVE',
      });
      expect(s.code, 'CS101');
      expect(s.name, 'Data Structures');
      expect(s.creditHours, '3');
      expect(s.department, 'Computer Science');
      expect(s.status, 'ACTIVE');
    });
  });
}
