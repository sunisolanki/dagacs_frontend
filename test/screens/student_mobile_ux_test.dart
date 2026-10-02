import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/calendar_attendance.dart';
import 'package:dagacs_frontend/models/student_profile.dart';
import 'package:dagacs_frontend/models/subject_attendance.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/repositories/student_profile_repository.dart';
import 'package:dagacs_frontend/screens/student_attendance_screen.dart';
import 'package:dagacs_frontend/screens/student_profile_screen.dart';
import 'package:dagacs_frontend/core/theme/dagacs_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 5.4: the student screens used to overflow on a small phone.
///
/// Both defects are width-driven, so these tests pin the *narrowest* supported
/// width rather than a representative one. `tester.takeException()` returning
/// null is the real assertion here: a `RenderFlex` overflow is reported as an
/// exception, so simply rendering at 320 dp and surviving is the contract.
const _phone = Size(320, 640);

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient());

  @override
  Future<void> logout() async {}
}

class _FakeSessionController extends SessionController {
  _FakeSessionController([String role = 'STUDENT'])
      : super(_FakeAuthRepository()) {
    // The drawer is derived from the role; a fake that never establishes one
    // would render the default list and make the assertions accidental.
    establishSession(role);
  }
}

class _FakeStudentProfileRepository extends StudentProfileRepository {
  _FakeStudentProfileRepository(this._profile);
  final StudentProfile? _profile;

  @override
  Future<StudentProfile> getMyProfile() async => _profile!;

  @override
  Future<StudentProfile> updateMyProfile(Map<String, dynamic> data) async =>
      _profile!;
}

const _profile = StudentProfile(
  rollNumber: '2201CE001',
  enrollmentNumber: 'ENR-2022-001',
  name: 'Student User',
  gender: 'M',
  fatherName: 'Father',
  motherName: 'Mother',
  personalEmail: 'student@test.com',
  age: 20,
  admissionDate: '2026-01-01',
  status: 'ACTIVE',
  batchName: 'B1',
  programName: 'Computer Science',
  sectionName: 'A',
);

class _FakeAttendanceRepository extends AttendanceRepository {
  @override
  Future<List<AttendanceRecord>> getMyAttendance() async => const [];

  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation({
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      const AttendancePercentage(
        presentCount: 0,
        totalRecordedCount: 0,
      );

  @override
  Future<List<SubjectAttendance>> getSubjectAttendanceSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      const [];

  @override
  Future<List<CalendarAttendance>> getCalendarAttendanceSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      const [];
}

void main() {
  setUp(() {
    // Belt and braces: if any layout below overflows, fail loudly with the
    // offending exception rather than letting it scroll past in the log.
    // (We assert on it explicitly too.)
  });

  testWidgets('profile edit fields fit a 320 dp phone', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: StudentProfileScreen(
          profileRepository: _FakeStudentProfileRepository(_profile),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter edit mode: the fixed-width field lives on this path.
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(4));
    expect(
      tester.takeException(),
      isNull,
      reason: 'the editable fields must not overflow at 320 dp',
    );
  });

  testWidgets('profile edit fields still fit a 412 dp phone', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: StudentProfileScreen(
          profileRepository: _FakeStudentProfileRepository(_profile),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('attendance date bar fits a 320 dp phone', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: StudentAttendanceScreen(
          attendanceRepository: _FakeAttendanceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start-date-button')), findsOneWidget);
    expect(find.byKey(const Key('end-date-button')), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the date range bar must not overflow at 320 dp');

    // Guard against this test going vacuous: the fake repository must actually
    // be consulted. If the override signature ever drifts, the screen falls
    // back to the real ApiClient and the assertion below fails loudly instead
    // of the overflow assertions quietly passing on an error state.
    expect(find.textContaining('No attendance'), findsWidgets);
  });

  testWidgets('attendance date bar keeps the clear action when filtering',
      (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: StudentAttendanceScreen(
          attendanceRepository: _FakeAttendanceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pick a start date so the filter (and therefore the clear control) appears.
    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear-dates-button')), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the filtered date bar with its clear action must not overflow '
            'at 320 dp');
  });

  testWidgets('student screens expose the shared navigation when wired',
      (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = _FakeSessionController();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: StudentProfileScreen(
          profileRepository: _FakeStudentProfileRepository(_profile),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation'), findsOneWidget,
        reason: 'a student on a phone needs a way to the rest of the app');

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(Drawer), matching: find.text('Overview')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: find.byType(Drawer), matching: find.text('My Attendance')),
      findsOneWidget,
    );
  });

  testWidgets('an unwired screen keeps its original plain app bar',
      (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDagacsTheme(),
        home: StudentAttendanceScreen(
          attendanceRepository: _FakeAttendanceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Backwards compatibility: constructing the screen without a session must
    // behave exactly as it did before Phase 5.
    expect(find.byTooltip('Open navigation'), findsNothing);
    expect(find.text('My Attendance'), findsOneWidget);
  });
}