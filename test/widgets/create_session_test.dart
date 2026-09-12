import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/attendance_session_create_request.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
import 'package:dagacs_frontend/screens/create_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sample = TeacherAssignment(
  id: 7,
  teacherId: 2,
  teacherEmail: 'a@college.edu',
  subjectOfferingId: 5,
  subjectId: 4,
  subjectCode: 'CS301',
  subjectName: 'DBMS',
  semesterId: 3,
  semesterName: 'Semester 3',
  sessionId: 1,
  sessionName: '2026-27',
  programId: 8,
  programName: 'B.Tech CSE',
  departmentId: 2,
  departmentName: 'Computer Science',
  sectionId: 9,
  sectionCode: 'A',
  sectionName: 'Section A',
  batchId: 6,
  batchCode: 'B1',
);

const _sample2 = TeacherAssignment(
  id: 8,
  teacherId: 2,
  teacherEmail: 'a@college.edu',
  subjectOfferingId: 6,
  subjectId: 5,
  subjectCode: 'CS302',
  subjectName: 'OS',
  semesterId: 4,
  semesterName: 'Semester 4',
  sessionId: 1,
  sessionName: '2026-27',
  programId: 8,
  programName: 'B.Tech CSE',
  departmentId: 2,
  departmentName: 'Computer Science',
  sectionId: 10,
  sectionCode: 'B',
  sectionName: 'Section B',
  batchId: 6,
  batchCode: 'B1',
);

/// Mirrors the screen's own `_assignmentContext` formatting so the dropdown
/// items are addressable in tests.
const _sampleLabel =
    'CS301 — DBMS · Semester 3 · 2026-27 — B.Tech CSE — Computer Science '
    '· Section A · B1';
const _sample2Label =
    'CS302 — OS · Semester 4 · 2026-27 — B.Tech CSE — Computer Science '
    '· Section B · B1';

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository();

  Future<AttendanceSession> Function(AttendanceSessionCreateRequest)?
      onCreateSession;
  List<AttendanceSession> Function()? onGetSessions;

  @override
  Future<AttendanceSession> createSession(
          AttendanceSessionCreateRequest request) =>
      onCreateSession != null
          ? onCreateSession!(request)
          : super.createSession(request);

  @override
  Future<List<AttendanceSession>> getSessions() async =>
      onGetSessions != null ? onGetSessions!() : const [];
}

class _FakeTeacherRepository extends TeacherRepository {
  _FakeTeacherRepository({this.assignments = const []});

  List<TeacherAssignment> assignments;
  bool failReads = false;

  @override
  Future<List<TeacherAssignment>> getMyAssignments() async {
    if (failReads) throw const ApiException.serverError();
    return List.of(assignments);
  }
}

class _PopProbe {
  dynamic result;
}

/// Pushes [screen] over a host route and records whatever the screen pops.
Future<_PopProbe> _push(WidgetTester tester, Widget screen) async {
  final probe = _PopProbe();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              probe.result = await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => screen));
            },
            child: const Text('open-form'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open-form'));
  await tester.pumpAndSettle();
  return probe;
}

void main() {
  testWidgets('shows validation errors for empty fields', (tester) async {
    final repo = _FakeAttendanceRepository();
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository:
                _FakeTeacherRepository(assignments: const [_sample]))));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pump();

    expect(find.text('Please select a class'), findsOneWidget);
    expect(find.text('Lecture period is required'), findsOneWidget);
    expect(find.text('Date is required'), findsOneWidget);
    expect(find.text('Subject ID is required'), findsNothing);
    expect(find.text('Section ID is required'), findsNothing);
  });

  testWidgets('rejects an impossible calendar date (2024-02-31)',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository: _FakeTeacherRepository(),
            preselectedAssignment: _sample)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '1st');
    await tester.enterText(find.byType(TextFormField).at(1), '2024-02-31');
    await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pump();

    expect(find.text('Enter a valid date (YYYY-MM-DD).'), findsOneWidget);
  });

  testWidgets('rejects a future date', (tester) async {
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-'
        '${tomorrow.day.toString().padLeft(2, '0')}';

    final repo = _FakeAttendanceRepository();
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository: _FakeTeacherRepository(),
            preselectedAssignment: _sample)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '1st');
    await tester.enterText(find.byType(TextFormField).at(1), tomorrowStr);
    await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pump();

    expect(find.text('Date cannot be in the future.'), findsOneWidget);
  });

  testWidgets('accepts today and a past date', (tester) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    AttendanceSessionCreateRequest? seen;
    final repo = _FakeAttendanceRepository()
      ..onCreateSession = (request) async {
        seen = request;
        return const AttendanceSession(id: 70);
      };
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository: _FakeTeacherRepository(),
            preselectedAssignment: _sample)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '1st');
    await tester.enterText(find.byType(TextFormField).at(1), todayStr);
    await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pumpAndSettle();

    expect(seen, isNotNull);
    expect(seen!.date, todayStr);
    expect(find.text('Enter a valid date (YYYY-MM-DD).'), findsNothing);
    expect(find.text('Date cannot be in the future.'), findsNothing);
  });

  testWidgets('removes manual Subject/Section entry and old banner',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository:
                _FakeTeacherRepository(assignments: const [_sample]))));
    await tester.pumpAndSettle();

    expect(find.text('Subject ID'), findsNothing);
    expect(find.byKey(const Key('create-session-submit')), findsOneWidget);
    expect(find.textContaining('teaching-assignment API'), findsNothing);
    expect(find.textContaining('Enter subject and section IDs'), findsNothing);
  });

  testWidgets('assignment dropdown lists only the teacher\'s assignments',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository: _FakeTeacherRepository(
                assignments: const [_sample, _sample2]))));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<TeacherAssignment>));
    await tester.pumpAndSettle();

    expect(find.text(_sampleLabel), findsOneWidget);
    expect(find.text(_sample2Label), findsOneWidget);
    expect(find.text('My Classes'), findsNothing);
  });

  testWidgets('creates a session from the selected assignment only',
      (tester) async {
    AttendanceSessionCreateRequest? seen;
    final repo = _FakeAttendanceRepository()
      ..onCreateSession = (request) async {
        seen = request;
        return const AttendanceSession(id: 55, subjectId: 4, sectionId: 9);
      };
    final probe = await _push(
        tester,
        CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository:
                _FakeTeacherRepository(assignments: const [_sample])));

    await tester.tap(find.byType(DropdownButtonFormField<TeacherAssignment>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_sampleLabel).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '1st');
    await tester.enterText(find.byType(TextFormField).at(1), '2026-09-04');
    await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pumpAndSettle();

    expect(seen, isNotNull);
    expect(seen!.subjectId, 4);
    expect(seen!.sectionId, 9);
    expect(seen!.lecturePeriod, '1st');
    expect(seen!.date, '2026-09-04');
    expect(seen!.toJson().keys.toSet(),
        {'subjectId', 'sectionId', 'lecturePeriod', 'date'});
    expect(seen!.toJson().containsKey('teacherId'), isFalse);
    expect((probe.result as AttendanceSession).id, 55);
  });

  testWidgets('preselects and locks the assignment from My Classes',
      (tester) async {
    AttendanceSessionCreateRequest? seen;
    final repo = _FakeAttendanceRepository()
      ..onCreateSession = (request) async {
        seen = request;
        return const AttendanceSession(id: 60);
      };
    final probe = await _push(
        tester,
        CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository: _FakeTeacherRepository(),
            preselectedAssignment: _sample));

    expect(find.byKey(const Key('preselected-class-lock')), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<TeacherAssignment>),
        findsNothing);
    expect(find.text(_sampleLabel), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '2nd');
    await tester.enterText(find.byType(TextFormField).at(1), '2026-09-05');
    await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pumpAndSettle();

    expect(seen!.subjectId, 4);
    expect(seen!.sectionId, 9);
    expect(seen!.lecturePeriod, '2nd');
    expect((probe.result as AttendanceSession).id, 60);
  });

  testWidgets('zero assignments disables submit with no manual fallback',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository: _FakeTeacherRepository())));
    await tester.pumpAndSettle();

    expect(find.text('No classes assigned yet. Contact your administrator.'),
        findsOneWidget);
    final submit =
        tester.widget<ElevatedButton>(find.byKey(const Key('create-session-submit')));
    expect(submit.onPressed, isNull);
    expect(find.byType(DropdownButtonFormField<TeacherAssignment>),
        findsNothing);
  });

  testWidgets('409 conflict resolves the existing session and opens it',
      (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onCreateSession =
          (_) async => throw const ApiException(409, 'Session already exists');
    repo.onGetSessions = () => const [
          AttendanceSession(
              id: 55,
              subjectId: 4,
              sectionId: 9,
              lecturePeriod: '1st',
              date: '2026-09-04',
              status: 'SCHEDULED'),
        ];
    final probe = await _push(
        tester,
        CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository:
                _FakeTeacherRepository(assignments: const [_sample])));

    await tester.tap(find.byType(DropdownButtonFormField<TeacherAssignment>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_sampleLabel).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '1st');
    await tester.enterText(find.byType(TextFormField).at(1), '2026-09-04');
    await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pumpAndSettle();

    expect(
        find.text('Attendance session already exists for this class and date.'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('duplicate-open-existing')));
    await tester.pumpAndSettle();

    expect((probe.result as AttendanceSession).id, 55);
  });

  testWidgets('409 conflict without a matching local session surfaces an error',
      (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onCreateSession =
          (_) async => throw const ApiException(409, 'Session already exists');
    repo.onGetSessions = () => const [];
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(
            attendanceRepository: repo,
            teacherRepository:
                _FakeTeacherRepository(assignments: const [_sample]))));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<TeacherAssignment>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_sampleLabel).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '1st');
    await tester.enterText(find.byType(TextFormField).at(1), '2026-09-04');
    await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('but it could not be opened'), findsOneWidget);
  });

  testWidgets('create session stays responsive at every width', (tester) async {
    final repo = _FakeAttendanceRepository();
    for (final size in const [
      Size(320, 720),
      Size(390, 844),
      Size(480, 800),
      Size(768, 1024),
      Size(1280, 800),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pump();

      await tester.pumpWidget(MaterialApp(
          home: CreateSessionScreen(
              attendanceRepository: repo,
              teacherRepository: _FakeTeacherRepository(
                  assignments: const [_sample]))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('create-session-submit')), findsOneWidget);
    }
  });
}