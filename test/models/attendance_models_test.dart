import 'package:dagacs_frontend/models/attendance_mark_item.dart';
import 'package:dagacs_frontend/models/attendance_mark_request.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/attendance_session_create_request.dart';
import 'package:dagacs_frontend/models/attendance_session_update_request.dart';
import 'package:dagacs_frontend/models/attendance_update_request.dart';
import 'package:dagacs_frontend/models/calendar_attendance.dart';
import 'package:dagacs_frontend/models/session_student.dart';
import 'package:dagacs_frontend/models/subject_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceSession', () {
    test('parses full DTO', () {
      final s = AttendanceSession.fromJson({
        'id': 1,
        'subjectId': 5,
        'subjectName': 'Data Structures',
        'sectionId': 2,
        'sectionName': 'CS-A',
        'teacherId': 10,
        'lecturePeriod': '1st Period',
        'date': '2026-09-04',
        'status': 'SCHEDULED',
        'createdAt': '2026-09-04T10:30:00',
      });
      expect(s.id, 1);
      expect(s.subjectId, 5);
      expect(s.subjectName, 'Data Structures');
      expect(s.sectionId, 2);
      expect(s.sectionName, 'CS-A');
      expect(s.teacherId, 10);
      expect(s.lecturePeriod, '1st Period');
      expect(s.date, '2026-09-04');
      expect(s.status, 'SCHEDULED');
      expect(s.createdAt, '2026-09-04T10:30:00');
    });

    test('handles missing optional fields', () {
      final s = AttendanceSession.fromJson({'id': 2});
      expect(s.id, 2);
      expect(s.subjectName, isNull);
      expect(s.status, isNull);
    });
  });

  group('AttendanceRecord', () {
    test('parses full DTO', () {
      final r = AttendanceRecord.fromJson({
        'id': 1,
        'studentId': 10,
        'subjectId': 5,
        'sectionId': 2,
        'status': 'PRESENT',
        'lecturePeriod': '1st Period',
        'date': '2026-09-04',
        'isPresent': true,
        'sessionId': 1,
        'markedById': 3,
        'markedByName': 'Dr. Smith',
        'createdAt': '2026-09-04T11:00:00',
      });
      expect(r.id, 1);
      expect(r.studentId, 10);
      expect(r.status, 'PRESENT');
      expect(r.isPresent, true);
      expect(r.sessionId, 1);
      expect(r.markedById, 3);
      expect(r.markedByName, 'Dr. Smith');
    });

    test('handles missing nullable fields', () {
      final r = AttendanceRecord.fromJson({'id': 2, 'status': 'ABSENT'});
      expect(r.studentId, isNull);
      expect(r.sessionId, isNull);
      expect(r.isPresent, isNull);
      expect(r.markedByName, isNull);
    });
  });

  group('SessionStudent', () {
    test('parses all fields', () {
      final s = SessionStudent.fromJson({
        'id': 10,
        'rollNumber': 'CS-A-001',
        'name': 'Alice Smith',
        'enrollmentNumber': 'ENG-2026-0001',
      });
      expect(s.id, 10);
      expect(s.rollNumber, 'CS-A-001');
      expect(s.name, 'Alice Smith');
      expect(s.enrollmentNumber, 'ENG-2026-0001');
    });

    test('handles missing fields', () {
      final s = SessionStudent.fromJson({});
      expect(s.id, isNull);
      expect(s.rollNumber, isNull);
      expect(s.name, isNull);
      expect(s.enrollmentNumber, isNull);
    });
  });

  group('AttendanceSessionCreateRequest', () {
    test('serializes to JSON', () {
      final r = AttendanceSessionCreateRequest(
        subjectId: 5,
        sectionId: 2,
        lecturePeriod: '1st Period',
        date: '2026-09-04',
      );
      final json = r.toJson();
      expect(json['subjectId'], 5);
      expect(json['sectionId'], 2);
      expect(json['lecturePeriod'], '1st Period');
      expect(json['date'], '2026-09-04');
    });
  });

  group('AttendanceSessionUpdateRequest', () {
    test('serializes to JSON', () {
      final r = AttendanceSessionUpdateRequest(
        lecturePeriod: '2nd Period',
        date: '2026-09-05',
        status: 'CONDUCTED',
      );
      final json = r.toJson();
      expect(json['lecturePeriod'], '2nd Period');
      expect(json['date'], '2026-09-05');
      expect(json['status'], 'CONDUCTED');
    });
  });

  group('AttendanceMarkItem', () {
    test('serializes to JSON', () {
      final item = AttendanceMarkItem(studentId: 10, status: 'PRESENT');
      final json = item.toJson();
      expect(json['studentId'], 10);
      expect(json['status'], 'PRESENT');
    });
  });

  group('AttendanceMarkRequest', () {
    test('serializes nested structure', () {
      final r = AttendanceMarkRequest(
        sessionId: 1,
        items: [
          AttendanceMarkItem(studentId: 10, status: 'PRESENT'),
          AttendanceMarkItem(studentId: 11, status: 'ABSENT'),
        ],
      );
      final json = r.toJson();
      expect(json['sessionId'], 1);
      final items = json['items'] as List;
      expect(items.length, 2);
      expect(items[0]['studentId'], 10);
      expect(items[0]['status'], 'PRESENT');
      expect(items[1]['studentId'], 11);
      expect(items[1]['status'], 'ABSENT');
    });
  });

  group('AttendanceUpdateRequest', () {
    test('serializes with optional reason', () {
      final r = AttendanceUpdateRequest(
        newStatus: 'ABSENT',
        reason: 'Late arrival',
      );
      final json = r.toJson();
      expect(json['newStatus'], 'ABSENT');
      expect(json['reason'], 'Late arrival');
    });

    test('serializes without reason', () {
      final r = AttendanceUpdateRequest(newStatus: 'PRESENT');
      final json = r.toJson();
      expect(json['newStatus'], 'PRESENT');
      expect(json.containsKey('reason'), isFalse);
    });
  });

  group('SubjectAttendance', () {
    test('parses all fields', () {
      final s = SubjectAttendance.fromJson({
        'subjectId': 5,
        'subjectName': 'Database Systems',
        'presentCount': 8,
        'totalRecordedCount': 10,
        'percentage': 80.0,
      });
      expect(s.subjectId, 5);
      expect(s.subjectName, 'Database Systems');
      expect(s.presentCount, 8);
      expect(s.totalRecordedCount, 10);
      expect(s.percentage, 80.0);
    });

    test('handles missing optional fields', () {
      final s = SubjectAttendance.fromJson({'subjectId': 5});
      expect(s.subjectId, 5);
      expect(s.subjectName, '');
      expect(s.presentCount, 0);
      expect(s.totalRecordedCount, 0);
      expect(s.percentage, isNull);
    });

    test('handles null subjectName', () {
      final s = SubjectAttendance.fromJson({
        'subjectId': 5,
        'subjectName': null,
        'presentCount': 3,
        'totalRecordedCount': 5,
      });
      expect(s.subjectName, '');
    });
  });

  group('CalendarAttendance', () {
    test('parses all fields', () {
      final c = CalendarAttendance.fromJson({
        'date': '2026-09-04',
        'presentCount': 3,
        'absentCount': 1,
        'totalRecordedCount': 4,
        'percentage': 75.0,
      });
      expect(c.date, '2026-09-04');
      expect(c.presentCount, 3);
      expect(c.absentCount, 1);
      expect(c.totalRecordedCount, 4);
      expect(c.percentage, 75.0);
    });

    test('handles missing optional fields', () {
      final c = CalendarAttendance.fromJson({'date': '2026-09-04'});
      expect(c.date, '2026-09-04');
      expect(c.presentCount, 0);
      expect(c.absentCount, 0);
      expect(c.totalRecordedCount, 0);
      expect(c.percentage, isNull);
    });

    test('handles null presentCount and absentCount', () {
      final c = CalendarAttendance.fromJson({
        'date': '2026-09-04',
        'presentCount': null,
        'absentCount': null,
      });
      expect(c.presentCount, 0);
      expect(c.absentCount, 0);
    });
  });
}
