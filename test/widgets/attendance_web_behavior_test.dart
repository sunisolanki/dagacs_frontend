import 'package:dagacs_frontend/models/attendance_mark_request.dart';
import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/attendance_update_request.dart';
import 'package:dagacs_frontend/models/session_student.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/screens/attendance_session_list_screen.dart';
import 'package:dagacs_frontend/screens/mark_attendance_screen.dart';
import 'package:dagacs_frontend/screens/student_attendance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake repository that tracks which methods were called and with what arguments.
class _TrackingAttendanceRepository extends AttendanceRepository {
  _TrackingAttendanceRepository();

  Future<List<AttendanceSession>> Function()? onGetSessions;
  Future<List<SessionStudent>> Function()? onGetStudents;
  Future<List<AttendanceRecord>> Function()? onGetRecords;
  Future<List<AttendanceRecord>> Function(AttendanceMarkRequest)? onMarkAttendance;
  Future<AttendanceRecord> Function(int, AttendanceUpdateRequest)? onUpdateAttendance;
  int getSessionsCallCount = 0;
  int getStudentsCallCount = 0;
  int getRecordsCallCount = 0;
  int markAttendanceCallCount = 0;
  int updateAttendanceCallCount = 0;

  @override
  Future<List<AttendanceSession>> getSessions() async {
    getSessionsCallCount++;
    return onGetSessions != null ? onGetSessions!() : super.getSessions();
  }

  @override
  Future<List<SessionStudent>> getStudentsForSession(int sessionId) async {
    getStudentsCallCount++;
    return onGetStudents != null ? onGetStudents!() : super.getStudentsForSession(sessionId);
  }

  @override
  Future<List<AttendanceRecord>> getRecordsForSession(int sessionId) async {
    getRecordsCallCount++;
    return onGetRecords != null ? onGetRecords!() : super.getRecordsForSession(sessionId);
  }

  @override
  Future<List<AttendanceRecord>> markAttendance(AttendanceMarkRequest req) async {
    markAttendanceCallCount++;
    return onMarkAttendance != null ? onMarkAttendance!(req) : super.markAttendance(req);
  }

  @override
  Future<AttendanceRecord> updateAttendance(int recordId, AttendanceUpdateRequest request) async {
    updateAttendanceCallCount++;
    return onUpdateAttendance != null ? onUpdateAttendance!(recordId, request) : super.updateAttendance(recordId, request);
  }
}

/// Fake repository for student attendance that tracks getMyAttendance calls.
class _TrackingStudentAttendanceRepository extends AttendanceRepository {
  _TrackingStudentAttendanceRepository();

  Future<List<AttendanceRecord>> Function()? onGetMyAttendance;
  int getMyAttendanceCallCount = 0;

  @override
  Future<List<AttendanceRecord>> getMyAttendance() async {
    getMyAttendanceCallCount++;
    return onGetMyAttendance != null ? onGetMyAttendance!() : super.getMyAttendance();
  }

  // The StudentAttendanceScreen now also consumes the M4.1 calculation APIs.
  // These stubs return a deterministic zero-record result so the frozen tests
  // do not attempt real network calls / hang on an endless loading spinner.
  // Note: when records fail, the whole-screen error path is exercised instead.
  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation(
          {DateTime? startDate, DateTime? endDate}) async =>
      const AttendancePercentage(presentCount: 0, totalRecordedCount: 0);

  @override
  Future<AttendancePercentage> getSubjectAttendanceCalculation(
          int subjectId,
          {DateTime? startDate, DateTime? endDate}) async =>
      const AttendancePercentage(presentCount: 0, totalRecordedCount: 0);
}

void main() {
  group('Attendance Web integration - session list rendering', () {
    testWidgets('attendance session list renders in MaterialApp widget-test context',
        (tester) async {
      final repo = _TrackingAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(
                id: 1,
                subjectName: 'Math',
                sectionName: 'A',
                date: '2026-09-04',
                lecturePeriod: '1st',
                status: 'SCHEDULED'),
          ];

      await tester.pumpWidget(MaterialApp(
        home: AttendanceSessionListScreen(attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Math'), findsOneWidget);
      expect(find.text('SCHEDULED'), findsOneWidget);
      expect(repo.getSessionsCallCount, 1);
    });

    testWidgets('session list error state is handled',
        (tester) async {
      final repo = _TrackingAttendanceRepository();
      repo.onGetSessions = () async => throw const ApiException.network();

      await tester.pumpWidget(MaterialApp(
        home: AttendanceSessionListScreen(attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to connect'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Attendance Web integration - CANCELLED session blocking', () {
    testWidgets('CANCELLED session blocks marking and hides SUBMIT',
        (tester) async {
      final repo = _TrackingAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'CANCELLED'),
          ];

      await tester.pumpWidget(MaterialApp(
        home: MarkAttendanceScreen(
            sessionId: 1, attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('SUBMIT'), findsNothing);
      expect(find.text('Unmarked'), findsNothing);
      expect(find.textContaining('cancelled'), findsOneWidget);
    });
  });

  group('Attendance Web integration - student attendance rendering', () {
    testWidgets('student attendance renders records in MaterialApp widget-test context',
        (tester) async {
      final repo = _TrackingStudentAttendanceRepository();
      repo.onGetMyAttendance = () async => [
            const AttendanceRecord(
                id: 1, subjectId: 5, status: 'PRESENT', isPresent: true,
                date: '2026-09-04', lecturePeriod: '1st'),
            const AttendanceRecord(
                id: 2, subjectId: 5, status: 'ABSENT', isPresent: false,
                date: '2026-09-04', lecturePeriod: '1st'),
          ];

      await tester.pumpWidget(MaterialApp(
        home: StudentAttendanceScreen(attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(repo.getMyAttendanceCallCount, 1);
    });

    testWidgets('student attendance empty state renders',
        (tester) async {
      final repo = _TrackingStudentAttendanceRepository();
      repo.onGetMyAttendance = () async => [];

      await tester.pumpWidget(MaterialApp(
        home: StudentAttendanceScreen(attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No attendance records found.'), findsOneWidget);
    });

    testWidgets('student attendance error state renders',
        (tester) async {
      final repo = _TrackingStudentAttendanceRepository();
      repo.onGetMyAttendance = () async => throw const ApiException.network();

      await tester.pumpWidget(MaterialApp(
        home: StudentAttendanceScreen(attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to connect'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Attendance Web integration - existing record PUT and new record POST', () {
    testWidgets('existing PRESENT record PUT is triggered on submit',
        (tester) async {
      final repo = _TrackingAttendanceRepository();
      repo.onGetSessions = () async => [const AttendanceSession(id: 1, status: 'SCHEDULED')];
      repo.onGetStudents = () async => [const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice')];
      repo.onGetRecords = () async => [const AttendanceRecord(id: 42, studentId: 1, status: 'PRESENT', isPresent: true)];
      repo.onUpdateAttendance = (recordId, request) async {
        return const AttendanceRecord(id: 42, studentId: 1, status: 'ABSENT', isPresent: false);
      };

      await tester.pumpWidget(MaterialApp(
        home: MarkAttendanceScreen(sessionId: 1, attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Present'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      expect(repo.updateAttendanceCallCount, 1);
      expect(repo.markAttendanceCallCount, 0);
    });

    testWidgets('new record batch POST is triggered when no existing records',
        (tester) async {
      final repo = _TrackingAttendanceRepository();
      repo.onGetSessions = () async => [const AttendanceSession(id: 1, status: 'SCHEDULED')];
      repo.onGetStudents = () async => [const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice')];
      repo.onGetRecords = () async => [];
      repo.onMarkAttendance = (req) async {
        return [const AttendanceRecord(id: 1, studentId: 1, status: 'PRESENT', isPresent: true)];
      };

      await tester.pumpWidget(MaterialApp(
        home: MarkAttendanceScreen(sessionId: 1, attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unmarked'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      expect(repo.markAttendanceCallCount, 1);
      expect(repo.updateAttendanceCallCount, 0);
    });

    testWidgets('UNMARKED student defaults to ABSENT on submit',
        (tester) async {
      final repo = _TrackingAttendanceRepository();
      repo.onGetSessions = () async => [const AttendanceSession(id: 1, status: 'SCHEDULED')];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
            const SessionStudent(id: 2, rollNumber: 'R2', name: 'Bob'),
          ];
      repo.onGetRecords = () async => [];
      repo.onMarkAttendance = (req) async {
        return [];
      };

      await tester.pumpWidget(MaterialApp(
        home: MarkAttendanceScreen(sessionId: 1, attendanceRepository: repo),
      ));
      await tester.pumpAndSettle();

      // Mark only Alice; Bob stays UNMARKED -> defaults to ABSENT
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      expect(repo.markAttendanceCallCount, 1);
      expect(repo.updateAttendanceCallCount, 0);
    });
  });
}
