import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/screens/home_screen.dart';
import 'package:dagacs_frontend/widgets/teacher_dashboard.dart';
import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<void> persistSession(AuthResponse auth) async {}

  @override
  Future<void> logout() async {}
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());
}

class _FakeTeacherRepository extends TeacherRepository {
  List<TeacherAssignment> assignments = const [];
  bool fail = false;

  @override
  Future<List<TeacherAssignment>> getMyAssignments() async {
    if (fail) throw const ApiException.network();
    return assignments;
  }
}

class _FakeAttendanceRepository extends AttendanceRepository {
  List<AttendanceSession> sessions = const [];
  bool fail = false;

  @override
  Future<List<AttendanceSession>> getSessions() async {
    if (fail) throw const ApiException.network();
    return sessions;
  }
}

const _assignments = [
  TeacherAssignment(
      id: 1,
      subjectId: 100,
      subjectCode: 'DS',
      subjectName: 'Data Structures',
      sectionId: 200,
      sectionCode: 'A',
      sectionName: 'CSE-A'),
  TeacherAssignment(
      id: 2,
      subjectId: 101,
      subjectCode: 'DBMS',
      subjectName: 'Database Systems',
      sectionId: 201,
      sectionCode: 'B',
      sectionName: 'CSE-B'),
];

const _sessions = [
  AttendanceSession(
      id: 11,
      subjectId: 100,
      subjectName: 'Data Structures',
      sectionId: 200,
      sectionName: 'CSE-A',
      date: '2026-01-10',
      lecturePeriod: 'LP1',
      status: 'CONDUCTED'),
  AttendanceSession(
      id: 12,
      subjectId: 100,
      subjectName: 'Data Structures',
      sectionId: 200,
      sectionName: 'CSE-A',
      date: '2026-01-12',
      lecturePeriod: 'LP1',
      status: 'SCHEDULED'),
];

SessionController _teacherSession() {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession('TEACHER', fullName: 'Asha Teacher');
  return session;
}

Widget _home({
  required _FakeTeacherRepository teachers,
  required _FakeAttendanceRepository attendance,
}) {
  return MaterialApp(
    home: HomeScreen(
      session: _teacherSession(),
      masterDataRepository: _FakeMasterDataRepository(),
      attendanceRepository: attendance,
      teacherRepository: teachers,
    ),
  );
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The dashboard is a non-scrolling section designed to be embedded in a host
/// scroll view (the home ListView). Standalone tests therefore give it a tall
/// surface instead of asserting on a 600px viewport it never ships into.
void _useTallViewport(WidgetTester tester) =>
    _useSize(tester, const Size(1000, 2400));

void main() {
  group('TeacherDashboard', () {
    testWidgets('renders classes, sessions and statistics', (tester) async {
      _useTallViewport(tester);
      final teachers = _FakeTeacherRepository()..assignments = _assignments;
      final attendance = _FakeAttendanceRepository()..sessions = _sessions;

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _dashboard(teachers, attendance))));
      await tester.pumpAndSettle();

      expect(find.byType(TeacherDashboard), findsOneWidget);
      expect(find.byKey(const Key('teacher-dashboard-classes')), findsOneWidget);
      expect(find.byKey(const Key('teacher-dashboard-sessions')),
          findsOneWidget);
      // Quick stats come from the real data.
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Conducted'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      // Class names and session metadata are visible.
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('2026-01-10 - LP1'), findsOneWidget);
    });

    testWidgets('shows conducted and scheduled status badges', (tester) async {
      _useTallViewport(tester);
      final teachers = _FakeTeacherRepository()..assignments = _assignments;
      final attendance = _FakeAttendanceRepository()..sessions = _sessions;

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _dashboard(teachers, attendance))));
      await tester.pumpAndSettle();

      expect(find.text('CONDUCTED'), findsOneWidget);
      expect(find.text('SCHEDULED'), findsOneWidget);
    });

    testWidgets('Take Attendance is available per class', (tester) async {
      _useTallViewport(tester);
      final teachers = _FakeTeacherRepository()..assignments = _assignments;
      final attendance = _FakeAttendanceRepository()..sessions = _sessions;
      final pushed = <String>[];

      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (settings) {
          pushed.add(settings.name ?? '');
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
        home: Scaffold(body: _dashboard(teachers, attendance)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacher-dashboard-take-attendance-1')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('teacher-dashboard-take-attendance-1')));
      await tester.pumpAndSettle();

      expect(pushed, contains(AppRoutes.createSession));
    });

    testWidgets('View all sessions navigates to Attendance Sessions',
        (tester) async {
      _useTallViewport(tester);
      final teachers = _FakeTeacherRepository()..assignments = _assignments;
      final attendance = _FakeAttendanceRepository()..sessions = _sessions;
      final pushed = <String>[];

      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (settings) {
          pushed.add(settings.name ?? '');
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
        home: Scaffold(body: _dashboard(teachers, attendance)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('teacher-dashboard-all-sessions')));
      await tester.pumpAndSettle();

      expect(pushed, contains(AppRoutes.teacherAttendance));
    });

    testWidgets('no assignments shows an empty hint, not an error',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: _dashboard(_FakeTeacherRepository(), _FakeAttendanceRepository()))));
      await tester.pumpAndSettle();

      expect(find.textContaining('No classes assigned yet'), findsOneWidget);
      expect(find.byKey(const Key('report-retry')), findsNothing);
    });

    testWidgets('API failure shows a retryable error', (tester) async {
      _useTallViewport(tester);
      final teachers = _FakeTeacherRepository()..fail = true;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: _dashboard(teachers, _FakeAttendanceRepository()))));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('loading state precedes the content', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: _dashboard(_FakeTeacherRepository(), _FakeAttendanceRepository()))));
      expect(find.text('Loading your dashboard...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Loading your dashboard...'), findsNothing);
    });
  });

  group('Teacher home wiring', () {
    testWidgets('a TEACHER home with repositories renders the dashboard',
        (tester) async {
      final teachers = _FakeTeacherRepository()..assignments = _assignments;
      final attendance = _FakeAttendanceRepository()..sessions = _sessions;

      await tester.pumpWidget(_home(teachers: teachers, attendance: attendance));
      await tester.pumpAndSettle();

      expect(find.byType(TeacherDashboard), findsOneWidget);
      expect(find.text('Data Structures'), findsOneWidget);
    });

    testWidgets('a TEACHER home without repositories keeps the plain tile list',
        (tester) async {
      final session = _teacherSession();
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          session: session,
          masterDataRepository: _FakeMasterDataRepository(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TeacherDashboard), findsNothing);
      expect(find.byKey(const Key('teacher-my-classes-tile')), findsOneWidget);
      expect(find.byKey(const Key('teacher-reports-tile')), findsOneWidget);
    });

    testWidgets('existing teacher module tiles are still reachable',
        (tester) async {
      final teachers = _FakeTeacherRepository()..assignments = _assignments;
      final attendance = _FakeAttendanceRepository()..sessions = _sessions;

      await tester.pumpWidget(_home(teachers: teachers, attendance: attendance));
      await tester.pumpAndSettle();

      // The dashboard must not swallow the established module entry points.
      expect(find.byKey(const Key('teacher-my-classes-tile')), findsOneWidget);
      expect(find.byKey(const Key('teacher-reports-tile')), findsOneWidget);
    });

    testWidgets('no overflow at 320 / 800 / 1280 px', (tester) async {
      for (final size in [
        const Size(320, 640),
        const Size(800, 600),
        const Size(1280, 800),
      ]) {
        _useSize(tester, size);
        final teachers = _FakeTeacherRepository()..assignments = _assignments;
        final attendance = _FakeAttendanceRepository()..sessions = _sessions;
        await tester.pumpWidget(
            _home(teachers: teachers, attendance: attendance));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'overflow at ${size.width}px');
        expect(find.byType(TeacherDashboard), findsOneWidget);
      }
    });
  });
}

Widget _dashboard(_FakeTeacherRepository teachers,
    _FakeAttendanceRepository attendance) {
  return TeacherDashboard(
    teacherRepository: teachers,
    attendanceRepository: attendance,
  );
}
