import 'package:dagacs_frontend/models/student_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies Dart model deserialization against the ACTUAL backend M5.1
/// `StudentProfileDTO` JSON shape (Jackson `non_null`).
void main() {
  group('StudentProfile', () {
    test('parses full DTO', () {
      final profile = StudentProfile.fromJson({
        'rollNumber': '2201CE001',
        'enrollmentNumber': 'ENR-2022-001',
        'name': 'Student User',
        'gender': 'M',
        'fatherName': 'Father',
        'motherName': 'Mother',
        'personalEmail': 'student@test.com',
        'photoUrl': 'url',
        'age': 20,
        'admissionDate': '2026-01-01',
        'status': 'ACTIVE',
        'batchName': 'B1',
        'programName': 'Computer Science',
        'sectionName': 'A',
      });
expect(profile.rollNumber, '2201CE001');
      expect(profile.enrollmentNumber, 'ENR-2022-001');
      expect(profile.name, 'Student User');
      expect(profile.gender, 'M');
      expect(profile.fatherName, 'Father');
      expect(profile.motherName, 'Mother');
      expect(profile.personalEmail, 'student@test.com');
      expect(profile.photoUrl, 'url');
      expect(profile.age, 20);
      expect(profile.admissionDate, '2026-01-01');
      expect(profile.status, 'ACTIVE');
      expect(profile.batchName, 'B1');
      expect(profile.programName, 'Computer Science');
      expect(profile.sectionName, 'A');
    });

    test('parses when optional fields are absent', () {
      final profile = StudentProfile.fromJson({
        'rollNumber': '2201CE002',
        'name': 'Rahul',
      });
      expect(profile.rollNumber, '2201CE002');
      expect(profile.name, 'Rahul');
      expect(profile.batchName, isNull);
      expect(profile.age, isNull);
    });

    test('toJson_includesOnlyEditableFields', () {
      final profile = StudentProfile(
        fatherName: 'Father',
        motherName: 'Mother',
        gender: 'M',
      );
      expect(profile.toJson(), {
        'fatherName': 'Father',
        'motherName': 'Mother',
        'gender': 'M',
      });
    });

    test('toJson_excludesAcademicFields', () {
      final profile = StudentProfile(
        rollNumber: '2201CE001',
        enrollmentNumber: 'ENR-2022-001',
        name: 'Student User',
        batchName: 'B1',
        programName: 'Computer Science',
        sectionName: 'A',
      );
      final json = profile.toJson();
      expect(json.containsKey('rollNumber'), isFalse);
      expect(json.containsKey('enrollmentNumber'), isFalse);
      expect(json.containsKey('name'), isFalse);
      expect(json.containsKey('batchName'), isFalse);
      expect(json.containsKey('programName'), isFalse);
      expect(json.containsKey('sectionName'), isFalse);
    });

    test('toJson_excludesEmail', () {
      final profile = StudentProfile(name: 'Student User');
      final json = profile.toJson();
      expect(json.containsKey('email'), isFalse);
    });

    test('toJson_includesPersonalEmail', () {
      final profile = StudentProfile(personalEmail: 'student@test.com');
      final json = profile.toJson();
      expect(json['personalEmail'], 'student@test.com');
    });
  });
}
