import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/core/theme/dagacs_theme.dart';
import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
import 'package:dagacs_frontend/screens/attendance_session_list_screen.dart';
import 'package:dagacs_frontend/screens/teacher_classes_screen.dart';
import 'package:dagacs_frontend/screens/teacher_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 5.5: the teacher's top-level module screens gained the shared
/// navigation frame so a phone user is never trapped on one module.
const _phone = Size(320, 640);

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient());

  @override
  Future<void> logout() async {}
}

class _FakeSessionController extends SessionController {
  _FakeSessionController([String role = 'TEACHER']) : super(_FakeAuthRepository()) {
    // The drawer content is derived from the role, so a fake that never
    // establishes one would silently render the default (student) list and
    // make these assertions meaningless.
    establishSession(role);
  }
}

class _FakeTeacherRepository extends TeacherRepository {
  _FakeTeacherRepository([List<TeacherAssignment>? assignments])
      : _assignments = List.of(assignments ?? const []);

  List<TeacherAssignment> _assignments;

  @override
  Future<List<TeacherAssignment>> getMyAssignments() async => _assignments;
}

class _FakeAttendanceRepository extends AttendanceRepository {
  @override
  Future<List<AttendanceSession>> getSessions() async => const [];
}

class _FakeReportRepository extends ReportRepository {}

/// A deliberately long assignment: a teacher's own subject, section and batch
/// names are the widest realistic strings on these cards, so they are the
/// honest stress case for a 320 dp screen.
final _longAssignment = TeacherAssignment(
  id: 1,
  subjectCode: 'CS-401-AP',
  subjectName: 'Advanced Database Management Systems',
  sessionName: 'Autumn Semester 2026',
  programName: 'Bachelor of Technology in Computer Science',
  sectionName: 'C',
  batchCode: '2023',
);

void main() {
  testWidgets('My Classes offers the drawer on a phone', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = _FakeSessionController();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: TeacherClassesScreen(
          teacherRepository: _FakeTeacherRepository([_longAssignment]),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'a long assignment card must not overflow at 320 dp');

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();

    final drawer = find.byType(Drawer);
    expect(find.descendant(of: drawer, matching: find.text('Overview')),
        findsOneWidget);
    // The teacher drawer mirrors the role's real destinations. "My Classes" is
    // reached from Overview rather than being a drawer destination of its own,
    // so the drawer must not invent an entry for it.
    expect(find.descendant(of: drawer, matching: find.text('Attendance')),
        findsOneWidget);
    expect(find.descendant(of: drawer, matching: find.text('Reports')),
        findsOneWidget);
    expect(find.descendant(of: drawer, matching: find.text('Sign out')),
        findsOneWidget);
  });

  testWidgets('Attendance Sessions offers the drawer on a phone',
      (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = _FakeSessionController();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: AttendanceSessionListScreen(
          attendanceRepository: _FakeAttendanceRepository(),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation'), findsOneWidget);
    // The create-session FAB must survive the scaffold swap.
    expect(find.byTooltip('Create session'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Overview')),
      findsOneWidget,
    );
  });

  testWidgets('Teacher Reports offers the drawer on a phone', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = _FakeSessionController();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: TeacherReportsScreen(
          reportRepository: _FakeReportRepository(),
          teacherRepository: _FakeTeacherRepository(),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher screens keep their plain app bar when unwired',
      (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: TeacherClassesScreen(
          teacherRepository: _FakeTeacherRepository([_longAssignment]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Backwards compatibility: no session means no drawer, exactly as before.
    expect(find.byTooltip('Open navigation'), findsNothing);
    expect(find.text('My Classes'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the unwired screen must still be overflow-free at 320 dp');
  });

  testWidgets('teacher screens keep desktop unchanged', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = _FakeSessionController();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: TeacherClassesScreen(
          teacherRepository: _FakeTeacherRepository([_longAssignment]),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation'), findsNothing,
        reason: 'a wide window has no drawer and no hamburger');
    expect(find.text('My Classes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}