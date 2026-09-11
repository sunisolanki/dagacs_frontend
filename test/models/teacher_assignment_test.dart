import 'package:dagacs_frontend/models/teacher.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Teacher.fromJson', () {
    test('maps every DTO field including nullable context', () {
      final teacher = Teacher.fromJson({
        'id': 4,
        'email': 'a@college.edu',
        'fullName': 'Dr A Sharma',
        'designation': 'Professor',
        'status': 'ACTIVE',
        'departmentId': 2,
        'departmentName': 'Computer Science',
      });
      expect(teacher.id, 4);
      expect(teacher.email, 'a@college.edu');
      expect(teacher.fullName, 'Dr A Sharma');
      expect(teacher.designation, 'Professor');
      expect(teacher.status, 'ACTIVE');
      expect(teacher.departmentId, 2);
      expect(teacher.departmentName, 'Computer Science');
    });

    test('tolerates absent optional fields', () {
      final teacher = Teacher.fromJson(const {'id': 4});
      expect(teacher.id, 4);
      expect(teacher.fullName, isNull);
      expect(teacher.designation, isNull);
      expect(teacher.departmentName, isNull);
    });
  });

  group('TeacherAssignment.fromJson', () {
    test('maps all derived context fields', () {
      final assignment = TeacherAssignment.fromJson({
        'id': 7,
        'teacherId': 2,
        'teacherName': 'Dr A Sharma',
        'teacherEmail': 'a@college.edu',
        'subjectOfferingId': 5,
        'subjectId': 4,
        'subjectCode': 'CS301',
        'subjectName': 'DBMS',
        'semesterId': 3,
        'semesterName': 'Semester 3',
        'sessionId': 1,
        'sessionName': '2026-27',
        'programId': 8,
        'programName': 'B.Tech CSE',
        'departmentId': 2,
        'departmentName': 'Computer Science',
        'sectionId': 9,
        'sectionCode': 'A',
        'sectionName': 'Section A',
        'batchId': 6,
        'batchCode': 'B1',
        'createdAt': '2026-09-01T10:00:00Z',
        'updatedAt': '2026-09-01T10:00:00Z',
      });
      expect(assignment.id, 7);
      expect(assignment.teacherId, 2);
      expect(assignment.teacherName, 'Dr A Sharma');
      expect(assignment.teacherEmail, 'a@college.edu');
      expect(assignment.subjectOfferingId, 5);
      expect(assignment.subjectId, 4);
      expect(assignment.subjectCode, 'CS301');
      expect(assignment.subjectName, 'DBMS');
      expect(assignment.semesterId, 3);
      expect(assignment.semesterName, 'Semester 3');
      expect(assignment.sessionId, 1);
      expect(assignment.sessionName, '2026-27');
      expect(assignment.programId, 8);
      expect(assignment.programName, 'B.Tech CSE');
      expect(assignment.departmentId, 2);
      expect(assignment.departmentName, 'Computer Science');
      expect(assignment.sectionId, 9);
      expect(assignment.sectionCode, 'A');
      expect(assignment.sectionName, 'Section A');
      expect(assignment.batchId, 6);
      expect(assignment.batchCode, 'B1');
      expect(assignment.createdAt, '2026-09-01T10:00:00Z');
      expect(assignment.updatedAt, '2026-09-01T10:00:00Z');
    });

    test('tolerates sparse payloads', () {
      final assignment =
          TeacherAssignment.fromJson(const {'id': 7, 'teacherId': 2});
      expect(assignment.id, 7);
      expect(assignment.teacherId, 2);
      expect(assignment.teacherName, isNull);
      expect(assignment.batchCode, isNull);
    });
  });

  group('TeacherAssignmentRequest.toJson', () {
    test('serializes exactly the three foreign identities', () {
      const request = TeacherAssignmentRequest(
          teacherId: 2, subjectOfferingId: 5, sectionId: 9);
      expect(request.toJson(), {
        'teacherId': 2,
        'subjectOfferingId': 5,
        'sectionId': 9,
      });
      // No context ids may sneak into the wire contract.
      expect(request.toJson().keys, hasLength(3));
    });
  });
}