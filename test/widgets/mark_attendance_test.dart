import 'package:dagacs_frontend/models/attendance_mark_request.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/attendance_update_request.dart';
import 'package:dagacs_frontend/models/session_student.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/screens/mark_attendance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository();
  Future<List<AttendanceSession>> Function()? onGetSessions;
  Future<List<SessionStudent>> Function()? onGetStudents;
  Future<List<AttendanceRecord>> Function()? onGetRecords;
  Future<List<AttendanceRecord>> Function(AttendanceMarkRequest)?
      onMarkAttendance;
  Future<AttendanceRecord> Function(int, AttendanceUpdateRequest)?
      onUpdateAttendance;

  @override
  Future<List<AttendanceSession>> getSessions() =>
      onGetSessions != null
          ? onGetSessions!()
          : super.getSessions();

  @override
  Future<List<SessionStudent>> getStudentsForSession(int sessionId) =>
      onGetStudents != null
          ? onGetStudents!()
          : super.getStudentsForSession(sessionId);

  @override
  Future<List<AttendanceRecord>> getRecordsForSession(int sessionId) =>
      onGetRecords != null
          ? onGetRecords!()
          : super.getRecordsForSession(sessionId);

  @override
  Future<List<AttendanceRecord>> markAttendance(AttendanceMarkRequest req) =>
      onMarkAttendance != null
          ? onMarkAttendance!(req)
          : super.markAttendance(req);

  @override
  Future<AttendanceRecord> updateAttendance(
          int recordId, AttendanceUpdateRequest request) =>
      onUpdateAttendance != null
          ? onUpdateAttendance!(recordId, request)
          : super.updateAttendance(recordId, request);
}

void main() {
  group('MarkAttendanceScreen', () {
    testWidgets('default state is UNMARKED for all students', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
            const SessionStudent(id: 2, rollNumber: 'R2', name: 'Bob'),
          ];
      repo.onGetRecords = () async => [];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Unmarked'), findsNWidgets(2));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('existing PRESENT record shows PRESENT', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
            const SessionStudent(id: 2, rollNumber: 'R2', name: 'Bob'),
          ];
      repo.onGetRecords = () async => [
            const AttendanceRecord(
                id: 10, studentId: 1, status: 'PRESENT', isPresent: true),
          ];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Unmarked'), findsOneWidget); // Bob
    });

    testWidgets('existing ABSENT record shows ABSENT', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords = () async => [
            const AttendanceRecord(
                id: 10, studentId: 1, status: 'ABSENT', isPresent: false),
          ];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Absent'), findsOneWidget);
    });

    testWidgets('submission blocked when any student is UNMARKED',
        (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
            const SessionStudent(id: 2, rollNumber: 'R2', name: 'Bob'),
          ];
      repo.onGetRecords = () async => [];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // Mark only Alice as PRESENT, leave Bob UNMARKED
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      expect(find.text('Please mark attendance for all students.'),
          findsOneWidget);
    });

    testWidgets('submission proceeds when all students are marked',
        (tester) async {
      AttendanceMarkRequest? captured;
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
            const SessionStudent(id: 2, rollNumber: 'R2', name: 'Bob'),
          ];
      repo.onGetRecords = () async => [];
      repo.onMarkAttendance = (req) async {
        captured = req;
        return [
          const AttendanceRecord(
              id: 1, studentId: 1, status: 'PRESENT', isPresent: true),
          const AttendanceRecord(
              id: 2, studentId: 2, status: 'ABSENT', isPresent: false),
        ];
      };

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // Mark Alice as PRESENT (tap once: UNMARKED -> PRESENT)
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();

      // Mark Bob as PRESENT (tap once: UNMARKED -> PRESENT)
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();

      // Tap Bob again: PRESENT -> ABSENT
      final presentBob = find.text('Present').last;
      await tester.tap(presentBob);
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.sessionId, 1);
      expect(captured!.items.length, 2);
      // Verify no UNMARKED sent to backend
      final statuses = captured!.items.map((i) => i.status).toSet();
      expect(statuses.contains('UNMARKED'), isFalse);
    });
  });

  // ── Fix 1: CANCELLED session detection ──────────────────────────────
  group('CANCELLED session', () {
    testWidgets('CANCELLED session disables marking controls', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'CANCELLED'),
          ];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('cancelled'), findsOneWidget);
      expect(find.text('Unmarked'), findsNothing);
      expect(find.text('Present'), findsNothing);
    });

    testWidgets('CANCELLED session hides SUBMIT button', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'CANCELLED'),
          ];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('SUBMIT'), findsNothing);
    });

    testWidgets('non-CANCELLED session allows marking', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords = () async => [];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('SUBMIT'), findsOneWidget);
      expect(find.text('Unmarked'), findsOneWidget);
    });

    testWidgets('CANCELLED detected from session list via getSessions',
        (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 2, status: 'SCHEDULED'),
            const AttendanceSession(id: 1, status: 'CANCELLED'),
          ];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('cancelled'), findsOneWidget);
      expect(find.text('SUBMIT'), findsNothing);
    });
  });

  // ── Fix 2: Existing record PUT update ──────────────────────────────
  group('existing record PUT update', () {
    testWidgets(
        'existing PRESENT changed to ABSENT calls PUT with correct recordId',
        (tester) async {
      int? capturedRecordId;
      AttendanceUpdateRequest? capturedRequest;
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords = () async => [
            const AttendanceRecord(
                id: 42, studentId: 1, status: 'PRESENT', isPresent: true),
          ];
      repo.onUpdateAttendance = (recordId, request) async {
        capturedRecordId = recordId;
        capturedRequest = request;
        return const AttendanceRecord(
            id: 42, studentId: 1, status: 'ABSENT', isPresent: false);
      };

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // Alice shows PRESENT; tap to toggle to ABSENT
      await tester.tap(find.text('Present'));
      await tester.pumpAndSettle();
      expect(find.text('Absent'), findsOneWidget);

      // Submit
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      expect(capturedRecordId, 42);
      expect(capturedRequest!.newStatus, 'ABSENT');
    });

    testWidgets('existing ABSENT changed to PRESENT calls PUT', (tester) async {
      int? capturedRecordId;
      AttendanceUpdateRequest? capturedRequest;
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords = () async => [
            const AttendanceRecord(
                id: 99, studentId: 1, status: 'ABSENT', isPresent: false),
          ];
      repo.onUpdateAttendance = (recordId, request) async {
        capturedRecordId = recordId;
        capturedRequest = request;
        return const AttendanceRecord(
            id: 99, studentId: 1, status: 'PRESENT', isPresent: true);
      };

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // Alice shows ABSENT; tap to toggle to UNMARKED
      await tester.tap(find.text('Absent'));
      await tester.pumpAndSettle();
      // Tap again: UNMARKED -> PRESENT
      await tester.tap(find.text('Unmarked'));
      await tester.pumpAndSettle();
      expect(find.text('Present'), findsOneWidget);

      // Submit
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      expect(capturedRecordId, 99);
      expect(capturedRequest!.newStatus, 'PRESENT');
    });

    testWidgets('new/unrecorded student uses batch POST not PUT',
        (tester) async {
      AttendanceMarkRequest? capturedMark;
      int? capturedRecordId;
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords = () async => [];
      repo.onMarkAttendance = (req) async {
        capturedMark = req;
        return [
          const AttendanceRecord(
              id: 1, studentId: 1, status: 'PRESENT', isPresent: true),
        ];
      };
      repo.onUpdateAttendance = (recordId, request) async {
        capturedRecordId = recordId;
        return const AttendanceRecord();
      };

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // Mark Alice PRESENT
      await tester.tap(find.text('Unmarked'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      // Batch POST was used, not PUT
      expect(capturedMark, isNotNull);
      expect(capturedMark!.items.length, 1);
      expect(capturedMark!.items.first.studentId, 1);
      expect(capturedRecordId, isNull);
    });

    testWidgets('existing record is NOT sent through batch POST',
        (tester) async {
      AttendanceMarkRequest? capturedMark;
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
            const SessionStudent(id: 2, rollNumber: 'R2', name: 'Bob'),
          ];
      repo.onGetRecords = () async => [
            const AttendanceRecord(
                id: 10, studentId: 1, status: 'PRESENT', isPresent: true),
          ];
      repo.onUpdateAttendance = (recordId, request) async {
        return const AttendanceRecord(
            id: 10, studentId: 1, status: 'ABSENT', isPresent: false);
      };
      repo.onMarkAttendance = (req) async {
        capturedMark = req;
        return [
          const AttendanceRecord(
              id: 20, studentId: 2, status: 'PRESENT', isPresent: true),
        ];
      };

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // Alice already shows PRESENT; toggle to ABSENT
      await tester.tap(find.text('Present'));
      await tester.pumpAndSettle();

      // Mark Bob as PRESENT
      await tester.tap(find.text('Unmarked'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      // Batch POST only contains Bob (studentId 2), not Alice
      expect(capturedMark, isNotNull);
      expect(capturedMark!.items.length, 1);
      expect(capturedMark!.items.first.studentId, 2);
    });

    testWidgets('UNMARKED is never sent to backend', (tester) async {
      AttendanceMarkRequest? capturedMark;
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
            const SessionStudent(id: 2, rollNumber: 'R2', name: 'Bob'),
          ];
      repo.onGetRecords = () async => [];
      repo.onMarkAttendance = (req) async {
        capturedMark = req;
        return [];
      };

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // Mark only Alice; Bob stays UNMARKED
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();

      // Attempt submit — should be blocked
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      // Submit was blocked, batch POST was never called
      expect(capturedMark, isNull);
      expect(find.text('Please mark attendance for all students.'),
          findsOneWidget);
    });

    testWidgets('update failure shows error and reverts local state',
        (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords = () async => [
            const AttendanceRecord(
                id: 42, studentId: 1, status: 'PRESENT', isPresent: true),
          ];
      repo.onUpdateAttendance = (recordId, request) async =>
          throw const ApiException(500, 'Server error');

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // Alice shows PRESENT; toggle to ABSENT
      await tester.tap(find.text('Present'));
      await tester.pumpAndSettle();
      expect(find.text('Absent'), findsOneWidget);

      // Submit — PUT fails, should revert to PRESENT
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();

      // Error shown via SnackBar
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      // Local state reverted back to PRESENT (list still visible)
      expect(find.text('Present'), findsOneWidget);
      // SUBMIT button still visible (not navigated away)
      expect(find.text('SUBMIT'), findsOneWidget);
    });

    testWidgets('CANCELLED session prevents PUT updates', (tester) async {
      int? capturedRecordId;
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'CANCELLED'),
          ];
      repo.onUpdateAttendance = (recordId, request) async {
        capturedRecordId = recordId;
        return const AttendanceRecord();
      };

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      // SUBMIT button should not exist
      expect(find.text('SUBMIT'), findsNothing);
      expect(capturedRecordId, isNull);
    });
  });

  // ── Fix 3: Record-load error surfacing ─────────────────────────────
  group('record-load error surfacing', () {
    testWidgets('403 while loading records shows error', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords =
          () async => throw const ApiException.forbidden();

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('not authorized'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('404 while loading records shows error', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords =
          () async => throw const ApiException.notFound();

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('not found'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('network error while loading records shows error',
        (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords =
          () async => throw const ApiException.network();

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to connect'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('200 empty list shows normal UNMARKED state', (tester) async {
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async => [
            const AttendanceSession(id: 1, status: 'SCHEDULED'),
          ];
      repo.onGetStudents = () async => [
            const SessionStudent(id: 1, rollNumber: 'R1', name: 'Alice'),
          ];
      repo.onGetRecords = () async => [];

      await tester.pumpWidget(MaterialApp(
          home: MarkAttendanceScreen(
              sessionId: 1, attendanceRepository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Unmarked'), findsOneWidget);
      expect(find.text('SUBMIT'), findsOneWidget);
    });
  });
}
