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