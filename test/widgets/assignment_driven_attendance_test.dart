import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/attendance_session_create_request.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
import 'package:dagacs_frontend/screens/attendance_session_list_screen.dart';
import 'package:dagacs_frontend/screens/create_session_screen.dart';
import 'package:dagacs_frontend/screens/home_screen.dart';
import 'package:dagacs_frontend/screens/teacher_classes_screen.dart';
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

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());
}

class _FakeTeacherRepository extends TeacherRepository {
  _FakeTeacherRepository({this.assignments = const []});
  List<TeacherAssignment> assignments;

  @override
  Future<List<TeacherAssignment>> getMyAssignments() async =>
      List.of(assignments);
}

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository({this.created});

  List<AttendanceSession> sessions = const [];
  AttendanceSession Function(AttendanceSessionCreateRequest)? created;
  AttendanceSessionCreateRequest? lastCreateRequest;

  @override
  Future<List<AttendanceSession>> getSessions() async => List.of(sessions);

  @override
  Future<AttendanceSession> createSession(
          AttendanceSessionCreateRequest request) async {
    lastCreateRequest = request;
    if (created != null) return created!(request);
    return const AttendanceSession(id: 1, subjectId: 4, sectionId: 9);
  }
}

SessionController _session(String role) {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession(role);
  return session;
}

Widget _home(String role) {
  return MaterialApp(
    home: HomeScreen(
      session: _session(role),
      masterDataRepository: _FakeMasterDataRepository(),
    ),
  );
}

void main() {
  group('Teacher home My Classes tile', () {
    testWidgets('TEACHER home displays the My Classes tile', (tester) async {
      await tester.pumpWidget(_home('TEACHER'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacher-my-classes-tile')), findsOneWidget);
      expect(find.text('My Classes'), findsOneWidget);
      expect(find.text('Your assigned classes with Take Attendance'),
          findsOneWidget);
    });

    testWidgets('tile appears for TEACHER only', (tester) async {
      for (final role in ['ADMIN', 'HOD', 'STUDENT']) {
        await tester.pumpWidget(_home(role));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('teacher-my-classes-tile')), findsNothing,
            reason: '$role must not receive the teacher My Classes tile');
      }
      await tester.pumpWidget(_home('TEACHER'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacher-my-classes-tile')), findsOneWidget);
    });

    testWidgets('tapping the tile routes to /teacher/classes', (tester) async {
      final pushed = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          session: _session('TEACHER'),
          masterDataRepository: _FakeMasterDataRepository(),
        ),
        onGenerateRoute: (settings) {
          pushed.add(settings.name ?? '');
          if (settings.name == AppRoutes.teacherClasses) {
            return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('my-classes-screen')));
          }
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('teacher-my-classes-tile')));
      await tester.pumpAndSettle();

      expect(pushed, contains(AppRoutes.teacherClasses));
    });
  });

  group('assignment-driven attendance flow', () {
    testWidgets(
        'My Classes → Take Attendance → create (preselected) → mark attendance',
        (tester) async {
      final teacherRepo = _FakeTeacherRepository(assignments: const [_sample]);
      final attendanceRepo = _FakeAttendanceRepository(
          created: (_) => const AttendanceSession(id: 55, subjectId: 4, sectionId: 9));
      int? markedSessionId;

      await tester.pumpWidget(MaterialApp(
        home: TeacherClassesScreen(teacherRepository: teacherRepo),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.createSession:
              return MaterialPageRoute(
                  builder: (_) => CreateSessionScreen(
                        attendanceRepository: attendanceRepo,
                        teacherRepository: teacherRepo,
                        preselectedAssignment:
                            settings.arguments is TeacherAssignment
                                ? settings.arguments as TeacherAssignment
                                : null,
                      ));
            case AppRoutes.markAttendance:
              markedSessionId = settings.arguments as int;
              return MaterialPageRoute(
                  builder: (_) =>
                      const Scaffold(body: Text('mark-attendance-screen')));
          }
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('my-class-take-attendance-7')));
      await tester.pumpAndSettle();

      // CreateSessionScreen opens with the assignment preselected and locked.
      expect(find.byKey(const Key('preselected-class-lock')), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<TeacherAssignment>),
          findsNothing);
      expect(find.textContaining('CS301 — DBMS'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '1st');
      await tester.enterText(find.byType(TextFormField).at(1), '2026-09-04');
      await tester.ensureVisible(find.byKey(const Key('create-session-submit')));
      await tester.tap(find.byKey(const Key('create-session-submit')));
      await tester.pumpAndSettle();

      // The request derives subjectId/sectionId from the assignment only.
      expect(attendanceRepo.lastCreateRequest, isNotNull);
      expect(attendanceRepo.lastCreateRequest!.subjectId, 4);
      expect(attendanceRepo.lastCreateRequest!.sectionId, 9);
      expect(attendanceRepo.lastCreateRequest!.toJson().containsKey('teacherId'),
          isFalse);

      // Flow continues into the existing marking engine.
      expect(find.text('mark-attendance-screen'), findsOneWidget);
      expect(markedSessionId, 55);
    });

    testWidgets('Attendance FAB opens CreateSessionScreen with assignment dropdown',
        (tester) async {
      final teacherRepo = _FakeTeacherRepository(assignments: const [_sample]);
      final attendanceRepo = _FakeAttendanceRepository();

      await tester.pumpWidget(MaterialApp(
        home: AttendanceSessionListScreen(attendanceRepository: attendanceRepo),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.createSession) {
            final arguments = settings.arguments;
            return MaterialPageRoute(
                builder: (_) => CreateSessionScreen(
                    attendanceRepository: attendanceRepo,
                    teacherRepository: teacherRepo,
                    preselectedAssignment: arguments is TeacherAssignment
                        ? arguments
                        : null));
          }
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Create session'));
      await tester.pumpAndSettle();

      // FAB path: no preselection, dropdown of the teacher's own assignments.
      expect(find.byType(DropdownButtonFormField<TeacherAssignment>),
          findsOneWidget);
      expect(find.byKey(const Key('preselected-class-lock')), findsNothing);
    });
  });
}