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

/// Local fake mirroring the architecture used by mark_attendance_test.dart.
/// The existing suites are deliberately left untouched.
class _FakeAttendanceRepository extends AttendanceRepository {
  Future<List<AttendanceSession>> Function()? onGetSessions;
  Future<List<SessionStudent>> Function()? onGetStudents;
  Future<List<AttendanceRecord>> Function()? onGetRecords;
  Future<List<AttendanceRecord>> Function(AttendanceMarkRequest)?
      onMarkAttendance;
  Future<AttendanceRecord> Function(int, AttendanceUpdateRequest)?
      onUpdateAttendance;

  @override
  Future<List<AttendanceSession>> getSessions() =>
      onGetSessions != null ? onGetSessions!() : super.getSessions();

  @override
  Future<List<SessionStudent>> getStudentsForSession(int sessionId) =>
      onGetStudents != null ? onGetStudents!() : super.getStudentsForSession(sessionId);

  @override
  Future<List<AttendanceRecord>> getRecordsForSession(int sessionId) =>
      onGetRecords != null ? onGetRecords!() : super.getRecordsForSession(sessionId);

  @override
  Future<List<AttendanceRecord>> markAttendance(AttendanceMarkRequest req) =>
      onMarkAttendance != null ? onMarkAttendance!(req) : super.markAttendance(req);

  @override
  Future<AttendanceRecord> updateAttendance(
          int recordId, AttendanceUpdateRequest request) =>
      onUpdateAttendance != null
          ? onUpdateAttendance!(recordId, request)
          : super.updateAttendance(recordId, request);
}

const _students = [
  SessionStudent(id: 1, name: 'Abhay Mishra', rollNumber: 'R-001', enrollmentNumber: '0801CS25BT01'),
  SessionStudent(id: 2, name: 'Rahul Sharma', rollNumber: 'R-002', enrollmentNumber: '0801CS25BT02'),
  SessionStudent(id: 3, name: 'Priya Nair', rollNumber: 'R-003', enrollmentNumber: '0801CS25BT03'),
];

_FakeAttendanceRepository _repo({
  List<SessionStudent> students = _students,
  List<AttendanceRecord> records = const [],
  String sessionStatus = 'SCHEDULED',
  Future<List<AttendanceRecord>> Function(AttendanceMarkRequest)? onMark,
}) {
  final repo = _FakeAttendanceRepository();
  repo.onGetSessions =
      () async => [AttendanceSession(id: 1, status: sessionStatus)];
  repo.onGetStudents = () async => students;
  repo.onGetRecords = () async => records;
  repo.onMarkAttendance = onMark ??
      (req) async => [
            for (final item in req.items)
              AttendanceRecord(
                  id: 100 + item.studentId,
                  studentId: item.studentId,
                  status: item.status,
                  isPresent: item.status == 'PRESENT'),
          ];
  return repo;
}

Widget _screen(AttendanceRepository repo) => MaterialApp(
      home: MarkAttendanceScreen(sessionId: 1, attendanceRepository: repo),
    );

/// Counter text is one rich string, e.g. "Present  2".
String _counter(String label, int count) => '$label  $count';

Future<void> _pump(WidgetTester tester, AttendanceRepository repo) async {
  await tester.pumpWidget(_screen(repo));
  await tester.pumpAndSettle();
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Roster size shown in the summary header.
String get _rosterLabel => '3 Students';

Future<void> _tapSelectAll(WidgetTester tester) async {
  await tester.tap(find.text('Select All'));
  await tester.pumpAndSettle();
}

void main() {
  group('MarkAttendanceScreen student-list UI', () {
    testWidgets('A. student list loads from the repository', (tester) async {
      await _pump(tester, _repo());
      expect(find.text('Abhay Mishra'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Nair'), findsOneWidget);
    });

    testWidgets('B. enrollment number is displayed', (tester) async {
      await _pump(tester, _repo());
      expect(find.text('Enrollment: 0801CS25BT01'), findsOneWidget);
      expect(find.text('Enrollment: 0801CS25BT02'), findsOneWidget);
      expect(find.text('Enrollment: 0801CS25BT03'), findsOneWidget);
    });

    testWidgets('C. roll number is not displayed in this UI', (tester) async {
      await _pump(tester, _repo());
      expect(find.textContaining('R-001'), findsNothing);
      expect(find.textContaining('R-002'), findsNothing);
      expect(find.textContaining('Roll:'), findsNothing);
      expect(find.textContaining('Roll '), findsNothing);
    });

    testWidgets('D. Select All marks every student Present', (tester) async {
      await _pump(tester, _repo());
      expect(find.text('Unmarked'), findsNWidgets(3));

      await _tapSelectAll(tester);

      expect(find.text('Present'), findsNWidgets(3));
      expect(find.text('Unmarked'), findsNothing);
    });

    testWidgets('E. Select All updates the counters immediately',
        (tester) async {
      await _pump(tester, _repo());
      // Counters appear in both the header and the sticky footer.
      expect(find.text(_counter('Present', 0)), findsNWidgets(2));
      expect(find.text(_counter('Absent', 0)), findsNWidgets(2));
      expect(find.text(_counter('Unmarked', 3)), findsNWidgets(2));

      await _tapSelectAll(tester);

      expect(find.text(_counter('Present', 3)), findsNWidgets(2));
      expect(find.text(_counter('Absent', 0)), findsNWidgets(2));
      expect(find.text(_counter('Unmarked', 0)), findsNWidgets(2));
    });

    testWidgets('F. individual student can be changed Present -> Absent',
        (tester) async {
      await _pump(tester, _repo());
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();
      expect(find.text(_counter('Present', 1)), findsNWidgets(2));

      await tester.tap(find.text('Present').first);
      await tester.pumpAndSettle();

      expect(find.text('Absent'), findsOneWidget);
      expect(find.text(_counter('Present', 0)), findsNWidgets(2));
      expect(find.text(_counter('Absent', 1)), findsNWidgets(2));
    });

    testWidgets('G. a student can be moved back to Present from Absent using '
        'the existing 3-state cycle', (tester) async {
      await _pump(tester, _repo());
      // The existing _toggleStatus cycles UNMARKED -> PRESENT -> ABSENT ->
      // UNMARKED, so returning to Present is two further taps. The cycle
      // itself is existing business logic and is not changed here.
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Present').first);
      await tester.pumpAndSettle();
      expect(find.text('Absent'), findsOneWidget);

      // ABSENT -> UNMARKED
      await tester.tap(find.text('Absent').first);
      await tester.pumpAndSettle();
      expect(find.text('Unmarked'), findsNWidgets(3));
      expect(find.text(_counter('Unmarked', 3)), findsNWidgets(2));

      // UNMARKED -> PRESENT
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();

      expect(find.text('Present'), findsOneWidget);
      expect(find.text(_counter('Present', 1)), findsNWidgets(2));
      expect(find.text(_counter('Absent', 0)), findsNWidgets(2));
    });

    testWidgets('H. unmarked counter stays consistent with the roster',
        (tester) async {
      await _pump(tester, _repo());
      // 3 = 0 present + 0 absent + 3 unmarked
      expect(find.text(_counter('Unmarked', 3)), findsNWidgets(2));

      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();
      // 3 = 1 + 0 + 2
      expect(find.text(_counter('Present', 1)), findsNWidgets(2));
      expect(find.text(_counter('Absent', 0)), findsNWidgets(2));
      expect(find.text(_counter('Unmarked', 2)), findsNWidgets(2));
      expect(find.text(_rosterLabel), findsOneWidget);
    });

    testWidgets('I. case B/C - fresh roster round-trips through Select All',
        (tester) async {
      await _pump(tester, _repo());

      await _tapSelectAll(tester);
      expect(find.text('Present'), findsNWidgets(3));

      // Unchecking restores the pre-Select-All baseline (all Unmarked).
      await _tapSelectAll(tester);
      expect(find.text('Unmarked'), findsNWidgets(3));
      expect(find.text(_counter('Unmarked', 3)), findsNWidgets(2));
    });

    testWidgets('J. case D - mixed persisted roster is restored, not wiped',
        (tester) async {
      // Alice PRESENT, Bob ABSENT, Priya has no record.
      final repo = _repo(
        records: const [
          AttendanceRecord(
              id: 11, studentId: 1, status: 'PRESENT', isPresent: true),
          AttendanceRecord(
              id: 12, studentId: 2, status: 'ABSENT', isPresent: false),
        ],
      );
      await _pump(tester, repo);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);

      await _tapSelectAll(tester);
      expect(find.text('Present'), findsNWidgets(3));

      // The dangerous case: deselect must NOT turn the roster into all Absent.
      await _tapSelectAll(tester);

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Unmarked'), findsOneWidget);
      expect(find.text(_counter('Present', 1)), findsNWidgets(2));
      expect(find.text(_counter('Absent', 1)), findsNWidgets(2));
      expect(find.text(_counter('Unmarked', 1)), findsNWidgets(2));
    });

    testWidgets('K. case E - all-persisted-Present roster is untouched by a '
        'select/deselect round trip', (tester) async {
      final repo = _repo(
        records: const [
          AttendanceRecord(
              id: 11, studentId: 1, status: 'PRESENT', isPresent: true),
          AttendanceRecord(
              id: 12, studentId: 2, status: 'PRESENT', isPresent: true),
          AttendanceRecord(
              id: 13, studentId: 3, status: 'PRESENT', isPresent: true),
        ],
      );
      await _pump(tester, repo);
      expect(find.text('Present'), findsNWidgets(3));

      await _tapSelectAll(tester);
      await _tapSelectAll(tester);

      // Every student keeps their persisted PRESENT status.
      expect(find.text('Present'), findsNWidgets(3));
      expect(find.text(_counter('Present', 3)), findsNWidgets(2));
      expect(find.text(_counter('Absent', 0)), findsNWidgets(2));
      expect(find.text(_counter('Unmarked', 0)), findsNWidgets(2));
    });

    testWidgets('L. case F - all-persisted-Absent roster is restored',
        (tester) async {
      final repo = _repo(
        records: const [
          AttendanceRecord(
              id: 11, studentId: 1, status: 'ABSENT', isPresent: false),
          AttendanceRecord(
              id: 12, studentId: 2, status: 'ABSENT', isPresent: false),
          AttendanceRecord(
              id: 13, studentId: 3, status: 'ABSENT', isPresent: false),
        ],
      );
      await _pump(tester, repo);
      expect(find.text('Absent'), findsNWidgets(3));

      await _tapSelectAll(tester);
      expect(find.text('Present'), findsNWidgets(3));

      await _tapSelectAll(tester);

      expect(find.text('Absent'), findsNWidgets(3));
      expect(find.text(_counter('Present', 0)), findsNWidgets(2));
      expect(find.text(_counter('Absent', 3)), findsNWidgets(2));
    });

    testWidgets('M. case A - fresh roster still defaults Unmarked to ABSENT '
        'on submit', (tester) async {
      AttendanceMarkRequest? captured;
      final repo = _repo(onMark: (req) async {
        captured = req;
        return [
          for (final item in req.items)
            AttendanceRecord(
                id: 200,
                studentId: item.studentId,
                status: item.status,
                isPresent: item.status == 'PRESENT'),
        ];
      });
      await _pump(tester, repo);

      // Mark one Present, leave the rest Unmarked, then submit.
      await tester.tap(find.text('Unmarked').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      final byStudent = {
        for (final item in captured!.items) item.studentId: item.status,
      };
      expect(byStudent[1], 'PRESENT');
      expect(byStudent[2], 'ABSENT');
      expect(byStudent[3], 'ABSENT');
    });

    testWidgets('N. sticky Submit Attendance uses the existing flow',
        (tester) async {
      AttendanceMarkRequest? captured;
      final repo = _repo(onMark: (req) async {
        captured = req;
        return [
          for (final item in req.items)
            AttendanceRecord(
                id: 300,
                studentId: item.studentId,
                status: item.status,
                isPresent: item.status == 'PRESENT'),
        ];
      });
      await _pump(tester, repo);
      await _tapSelectAll(tester);

      expect(find.text('Submit Attendance'), findsOneWidget);
      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.sessionId, 1);
      expect(captured!.items.length, 3);
      expect(
        captured!.items.every((i) => i.status == 'PRESENT'),
        isTrue,
      );
    });

    testWidgets('O. AppBar SUBMIT and sticky button share one submission path',
        (tester) async {
      var markCalls = 0;
      AttendanceMarkRequest? captured;
      final repo = _repo(onMark: (req) async {
        markCalls++;
        captured = req;
        return [
          for (final item in req.items)
            AttendanceRecord(
                id: 400,
                studentId: item.studentId,
                status: item.status,
                isPresent: item.status == 'PRESENT'),
        ];
      });
      await _pump(tester, repo);
      await _tapSelectAll(tester);

      // Both affordances exist and the sticky one calls the same _submit().
      expect(find.text('SUBMIT'), findsOneWidget);
      expect(find.text('Submit Attendance'), findsOneWidget);
      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      expect(markCalls, 1);
      expect(captured, isNotNull);
    });

    testWidgets('P. no hard block: submit proceeds with students Unmarked',
        (tester) async {
      var markCalls = 0;
      final repo = _repo(onMark: (req) async {
        markCalls++;
        return [
          for (final item in req.items)
            AttendanceRecord(
                id: 500,
                studentId: item.studentId,
                status: item.status,
                isPresent: item.status == 'PRESENT'),
        ];
      });
      await _pump(tester, repo);

      // Nothing marked at all: 3 Unmarked.
      expect(find.text(_counter('Unmarked', 3)), findsNWidgets(2));
      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      // Existing business rule preserved: submission is not blocked.
      expect(markCalls, 1);
    });

    testWidgets('Q. existing records still use PUT and new ones batch POST',
        (tester) async {
      final putIds = <int>[];
      final repo = _repo(
        students: _students,
        records: const [
          AttendanceRecord(
              id: 11, studentId: 1, status: 'PRESENT', isPresent: true),
        ],
      );
      repo.onUpdateAttendance = (recordId, request) async {
        putIds.add(recordId);
        return AttendanceRecord(
            id: recordId,
            studentId: 1,
            status: request.newStatus,
            isPresent: request.newStatus == 'PRESENT');
      };
      AttendanceMarkRequest? captured;
      repo.onMarkAttendance = (req) async {
        captured = req;
        return [
          for (final item in req.items)
            AttendanceRecord(
                id: 600 + item.studentId,
                studentId: item.studentId,
                status: item.status,
                isPresent: item.status == 'PRESENT'),
        ];
      };

      await _pump(tester, repo);
      await _tapSelectAll(tester);
      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      // Student 1 already had a record -> PUT; students 2 and 3 -> batch POST.
      expect(putIds, [11]);
      expect(captured, isNotNull);
      final posted = captured!.items.map((i) => i.studentId).toSet();
      expect(posted, {2, 3});
    });

    testWidgets('R. empty roster shows the empty state', (tester) async {
      await _pump(tester, _repo(students: const []));
      expect(find.text('No students are available for this session.'),
          findsOneWidget);
      expect(find.text('Select All'), findsNothing);
    });

    testWidgets('S. loading state is shown while fetching', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_screen(repo));
      expect(find.text('Loading students...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Loading students...'), findsNothing);
    });

    testWidgets('T. API error shows the error state and retries',
        (tester) async {
      var attempts = 0;
      final repo = _FakeAttendanceRepository();
      repo.onGetSessions = () async {
        if (attempts++ == 0) throw const ApiException.network();
        return [const AttendanceSession(id: 1, status: 'SCHEDULED')];
      };
      repo.onGetStudents = () async => _students;
      repo.onGetRecords = () async => const [];
      repo.onMarkAttendance = (req) async => const [];

      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Abhay Mishra'), findsOneWidget);
    });

    testWidgets('U. cancelled session blocks marking', (tester) async {
      await _pump(tester, _repo(sessionStatus: 'CANCELLED'));
      expect(
        find.text('This session is cancelled. Attendance cannot be marked.'),
        findsOneWidget,
      );
      expect(find.text('Select All'), findsNothing);
      expect(find.text('Submit Attendance'), findsNothing);
    });

    testWidgets('V. a student without an id is excluded from counters',
        (tester) async {
      await _pump(tester, _repo(students: const [
        SessionStudent(id: 1, name: 'Markable', enrollmentNumber: 'E-1'),
        SessionStudent(name: 'No Id', enrollmentNumber: 'E-2'),
      ]));

      // Roster size counts only markable students.
      expect(find.text('1 Student'), findsOneWidget);
      // The id-less row is visible but not counted as Unmarked.
      expect(find.text('No Id'), findsOneWidget);
      expect(find.text(_counter('Unmarked', 1)), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await _tapSelectAll(tester);
      expect(find.text('Present'), findsOneWidget);
    });

    for (final size in [
      const Size(320, 640),
      const Size(800, 600),
      const Size(1280, 800),
    ]) {
      testWidgets('W. no overflow at ${size.width.toInt()}px', (tester) async {
        _useSize(tester, size);
        await _pump(tester, _repo(records: const [
          AttendanceRecord(
              id: 11, studentId: 1, status: 'PRESENT', isPresent: true),
        ]));
        expect(find.text('Abhay Mishra'), findsOneWidget);
      });
    }
  });
}
