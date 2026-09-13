import 'package:dagacs_frontend/models/student_management.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies Dart model deserialization against the ACTUAL backend M5.2 JSON
/// shapes (`StudentManagementDTO` / `StudentManagementRequestDTO`, Jackson
/// `non_null`).
void main() {
  group('StudentManagement.fromJson', () {
    test('parses full DTO', () {
      final student = StudentManagement.fromJson({
        'id': 3,
        'rollNumber': '2201CE001',
        'email': 'student1@dagacs.local',
        'name': 'Rahul Kumar',
        'gender': 'M',
        'fatherName': 'Father',
        'motherName': 'Mother',
        'photoUrl': 'url',
        'enrollmentNumber': 'ENR-001',
        'age': 20,
        'admissionDate': '2026-01-01',
        'status': 'ACTIVE',
        'programId': 1,
        'programName': 'Computer Science',
        'batchId': 1,
        'batchName': 'B1',
        'sectionId': 1,
        'sectionName': 'A',
      });
      expect(student.id, 3);
      expect(student.rollNumber, '2201CE001');
      expect(student.name, 'Rahul Kumar');
      expect(student.email, 'student1@dagacs.local');
      expect(student.status, 'ACTIVE');
      expect(student.programName, 'Computer Science');
      expect(student.batchName, 'B1');
      expect(student.sectionName, 'A');
      expect(student.isActive, isTrue);
    });

    test('parses when optional fields are absent', () {
      final student = StudentManagement.fromJson({
        'id': 4,
        'rollNumber': '2201CE002',
        'name': 'Rahul',
        'status': 'INACTIVE',
      });
      expect(student.rollNumber, '2201CE002');
      expect(student.email, isNull);
      expect(student.programName, isNull);
      expect(student.isActive, isFalse);
      expect(student.hasLogin, isFalse);
    });

    test('parses M9.5.2 login-linkage fields', () {
      final student = StudentManagement.fromJson({
        'id': 6,
        'rollNumber': '2201CE004',
        'name': 'Zoya',
        'status': 'ACTIVE',
        'loginLinked': true,
        'loginStatus': 'ACTIVE',
      });
      expect(student.hasLogin, isTrue);
      expect(student.loginIsActive, isTrue);
      expect(student.loginStatus, 'ACTIVE');
    });

    test('parses a linked-but-deactivated login', () {
      final student = StudentManagement.fromJson({
        'id': 7,
        'rollNumber': '2201CE005',
        'name': 'Arjun',
        'status': 'ACTIVE',
        'loginLinked': true,
        'loginStatus': 'INACTIVE',
      });
      expect(student.hasLogin, isTrue);
      expect(student.loginIsActive, isFalse);
    });

    test('parses M10A first-login fields', () {
      final student = StudentManagement.fromJson({
        'id': 8,
        'rollNumber': '2201CE006',
        'name': 'Kiran',
        'status': 'ACTIVE',
        'loginLinked': true,
        'loginStatus': 'ACTIVE',
        'mustChangePassword': true,
        'temporaryPassword': 'Temp#Pass1',
        'credentialDownloadId': 'dl-abcd-1234',
      });
      expect(student.mustChangePassword, isTrue);
      expect(student.temporaryPassword, 'Temp#Pass1');
      expect(student.credentialDownloadId, 'dl-abcd-1234');
    });

    test('M10A fields default to null when absent', () {
      final student = StudentManagement.fromJson({
        'id': 9,
        'rollNumber': '2201CE007',
        'name': 'Sana',
        'status': 'ACTIVE',
      });
      expect(student.mustChangePassword, isNull);
      expect(student.temporaryPassword, isNull);
      expect(student.credentialDownloadId, isNull);
    });
  });

  group('StudentImportResult.fromJson', () {
    test('parses credentialDownloadId on success', () {
      final result = StudentImportResult.fromJson({
        'totalRows': 2,
        'importedRows': 2,
        'rejectedRows': 0,
        'message': 'Imported 2 students',
        'credentialDownloadId': 'dl-xyz-999',
        'errors': [],
      });
      expect(result.isSuccess, isTrue);
      expect(result.credentialDownloadId, 'dl-xyz-999');
    });

    test('credentialDownloadId is null when absent or rejected', () {
      final result = StudentImportResult.fromJson({
        'totalRows': 2,
        'importedRows': 0,
        'rejectedRows': 2,
        'message': 'Rejected',
        'errors': [
          {'rowNumber': 2, 'field': 'email', 'message': 'bad', 'status': 400}
        ],
      });
      expect(result.isSuccess, isFalse);
      expect(result.credentialDownloadId, isNull);
    });
  });

  group('StudentLoginPasswordRequest', () {
    test('serializes the write-only password', () {
      const request = StudentLoginPasswordRequest('TempPass#1');
      expect(request.toJson(), {'password': 'TempPass#1'});
    });
  });

  group('StudentManagementRequest', () {
    test('toJson includes only non-null values', () {
      const request = StudentManagementRequest(
        rollNumber: '2201CE001',
        name: 'Rahul Kumar',
        status: 'ACTIVE',
        programId: 1,
        batchId: 1,
        sectionId: 1,
      );
      final json = request.toJson();
      expect(json['rollNumber'], '2201CE001');
      expect(json['name'], 'Rahul Kumar');
      expect(json['status'], 'ACTIVE');
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('age'), isFalse);
      expect(json.containsKey('photoUrl'), isFalse);
    });

    test('fromStudent copies display model fields', () {
      final student = StudentManagement.fromJson({
        'id': 5,
        'rollNumber': '2201CE003',
        'name': 'Anjali',
        'status': 'INACTIVE',
        'programId': 2,
        'batchId': 3,
        'sectionId': 4,
        'age': 21,
        'email': 'a@dagacs.local',
      });
      final request = StudentManagementRequest.fromStudent(student);
      expect(request.rollNumber, '2201CE003');
      expect(request.name, 'Anjali');
      expect(request.status, 'INACTIVE');
      expect(request.programId, 2);
      expect(request.batchId, 3);
      expect(request.sectionId, 4);
      expect(request.age, 21);
      expect(request.email, 'a@dagacs.local');
    });
  });
}