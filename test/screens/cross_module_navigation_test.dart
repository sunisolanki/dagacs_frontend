import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/models/batch.dart';
import 'package:dagacs_frontend/models/hod_audit_log_entry.dart';
import 'package:dagacs_frontend/models/hod_coverage_row.dart';
import 'package:dagacs_frontend/models/hod_daily_lecture_row.dart';
import 'package:dagacs_frontend/models/hod_dashboard.dart';
import 'package:dagacs_frontend/models/hod_low_attendance.dart';
import 'package:dagacs_frontend/models/hod_rollup.dart';
import 'package:dagacs_frontend/models/hod_section_attendance.dart';
import 'package:dagacs_frontend/models/hod_student_attendance.dart';
import 'package:dagacs_frontend/models/hod_subject_attendance.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/report_page.dart';
import 'package:dagacs_frontend/models/section.dart';
import 'package:dagacs_frontend/models/student_management.dart';
import 'package:dagacs_frontend/models/student_profile.dart';
import 'package:dagacs_frontend/models/teacher_report_row.dart';
import 'package:dagacs_frontend/models/teacher_management.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/hod_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
import 'package:dagacs_frontend/repositories/student_management_repository.dart';
import 'package:dagacs_frontend/repositories/student_profile_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_management_repository.dart';
import 'package:dagacs_frontend/screens/attendance_session_list_screen.dart';
import 'package:dagacs_frontend/screens/hod_dashboard_screen.dart';
import 'package:dagacs_frontend/screens/hod_reports_screen.dart';
import 'package:dagacs_frontend/screens/home_screen.dart';
import 'package:dagacs_frontend/screens/master_data_screen.dart';
import 'package:dagacs_frontend/screens/student_attendance_screen.dart';
import 'package:dagacs_frontend/screens/student_management_screen.dart';
import 'package:dagacs_frontend/screens/student_profile_screen.dart';
import 'package:dagacs_frontend/screens/teacher_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the names of pushed routes so tests can assert the actual route
/// destination, not just the existence of a widget.
class _RouteObserver extends NavigatorObserver {
  final List<String> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());

  @override
  Future<List<Program>> getPrograms() async =>
      const [Program(id: 1, name: 'Computer Science', code: 'CS')];

  @override
  Future<List<Batch>> getBatches() async =>
      const [Batch(id: 1, name: 'B1', batchCode: 'B1')];

  @override
  Future<List<Section>> getSections() async =>
      const [Section(id: 1, name: 'A', sectionCode: 'A')];
}

class _FakeTeacherManagementRepository extends TeacherManagementRepository {
  _FakeTeacherManagementRepository() : super(ApiClient());

  @override
  Future<List<TeacherManagement>> getTeachers() async => const [];
}

class _FakeStudentManagementRepository extends StudentManagementRepository {
  _FakeStudentManagementRepository() : super(ApiClient());

  @override
  Future<List<StudentManagement>> getStudents() async => const [];
}

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository();

  @override
  Future<List<AttendanceSession>> getSessions() async => const [];

  @override
  Future<List<AttendanceRecord>> getMyAttendance() async => const [];

  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation(
      {DateTime? startDate, DateTime? endDate}) async =>
      throw const ApiException.network();

  @override
  Future<AttendancePercentage> getSubjectAttendanceCalculation(
      int subjectId,
      {DateTime? startDate,
      DateTime? endDate}) async =>
      throw const ApiException.network();
}

class _FakeHodRepository extends HodRepository {
  _FakeHodRepository();

  @override
  Future<HodDashboard> getDashboard(
      {DateTime? startDate, DateTime? endDate}) async =>
      const HodDashboard(
        departmentName: 'Computer Engineering',
        departmentCode: 'CE',
        programCount: 0,
        batchCount: 0,
        sectionCount: 0,
        studentCount: 0,
        totalRecordedCount: 0,
        presentCount: 0,
        overallPercentage: null,
      );

  @override
  Future<List<HodSectionAttendance>> getSections(
      {DateTime? startDate, DateTime? endDate}) async =>
      const [];

  @override
  Future<List<HodSubjectAttendance>> getSubjects(
      {DateTime? startDate, DateTime? endDate}) async =>
      const [];

  @override
  Future<List<HodStudentAttendance>> getStudents(
      {DateTime? startDate, DateTime? endDate}) async =>
      const [];

  @override
  Future<List<HodLowAttendance>> getLowAttendance(
      {DateTime? startDate, DateTime? endDate}) async =>
      const [];

  @override
  Future<List<HodRollup>> getRollups(
      {required String type,
      DateTime? startDate,
      DateTime? endDate}) async =>
      const [];

  @override
  Future<List<HodAuditLogEntry>> getAuditLogs(
      {DateTime? startDate, DateTime? endDate}) async =>
      const [];
}

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository();

  @override
  Future<ReportPage<HodDailyLectureRow>> getDailyLecture(
      {int page = 0,
      int size = ReportRepository.defaultPageSize,
      DateTime? startDate,
      DateTime? endDate}) async =>
      const ReportPage<HodDailyLectureRow>(items: [], page: 0, totalPages: 0);

  @override
  Future<ReportPage<HodCoverageRow>> getCoverage(
      {int page = 0,
      int size = ReportRepository.defaultPageSize,
      DateTime? startDate,
      DateTime? endDate}) async =>
      const ReportPage<HodCoverageRow>(items: [], page: 0, totalPages: 0);

  @override
  Future<List<TeacherReportRow>> getTeacherReport(
      {DateTime? startDate, DateTime? endDate}) async =>
      const [];
}

class _FakeStudentProfileRepository extends StudentProfileRepository {
  _FakeStudentProfileRepository();

  @override
  Future<StudentProfile> getMyProfile() async =>
      const StudentProfile(name: 'Student S', rollNumber: 'S-1');
}

/// Mirrors the `main.dart` route table, but with repository fakes so navigation
/// is exercised without a backend or platform plugins. Home is the initial
/// screen so the role-gated tiles are the navigation entry point.
MaterialApp _buildApp(String role, _RouteObserver observer) {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession(role);
  final master = _FakeMasterDataRepository();
  final studentManagement = _FakeStudentManagementRepository();
  final attendance = _FakeAttendanceRepository();
  final hod = _FakeHodRepository();
  final reports = _FakeReportRepository();
  final profile = _FakeStudentProfileRepository();

  return MaterialApp(
    navigatorObservers: [observer],
    home: HomeScreen(session: session, masterDataRepository: master),
    onGenerateRoute: (settings) {
      switch (settings.name) {
        case '/admin/students':
          return MaterialPageRoute(
              settings: settings,
              builder: (_) => StudentManagementScreen(
                  repository: studentManagement,
                  masterDataRepository: master));
        case '/hod/dashboard':
          return MaterialPageRoute(
              settings: settings,
              builder: (_) => HodDashboardScreen(hodRepository: hod));
        case '/hod/reports':
          return MaterialPageRoute(
              settings: settings,
              builder: (_) =>
                  HodReportsScreen(hodRepository: hod, reportRepository: reports));
        case '/teacher/attendance':
          return MaterialPageRoute(
              settings: settings,
              builder: (_) =>
                  AttendanceSessionListScreen(attendanceRepository: attendance));
        case '/teacher/reports':
          return MaterialPageRoute(
              settings: settings,
              builder: (_) => TeacherReportsScreen(reportRepository: reports));
        case '/student/attendance':
          return MaterialPageRoute(
              settings: settings,
              builder: (_) =>
                  StudentAttendanceScreen(attendanceRepository: attendance));
        case '/student/profile':
          return MaterialPageRoute(
              settings: settings,
              builder: (_) => StudentProfileScreen(profileRepository: profile));
        case '/master-data':
          return MaterialPageRoute(
              settings: settings,
              builder: (_) => MasterDataScreen(
                    repository: master,
                    teacherManagementRepository:
                        _FakeTeacherManagementRepository(),
                    session: session,
                  ));
        default:
          return MaterialPageRoute(
              settings: settings, builder: (_) => const SizedBox());
      }
    },
  );
}

Future<void> _pumpRole(
    WidgetTester tester, _RouteObserver observer, String role) async {
  await tester.binding.setSurfaceSize(const Size(2000, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_buildApp(role, observer));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'ADMIN home exposes only the students module and navigates to /admin/students',
      (tester) async {
    final observer = _RouteObserver();
    await _pumpRole(tester, observer, 'ADMIN');

    // Authorized control is exposed.
    expect(find.byKey(const Key('admin-students-tile')), findsOneWidget);
    expect(find.text('Manage Students'), findsOneWidget);
    expect(find.byKey(const Key('admin-master-data-tile')), findsOneWidget);
    expect(find.text('Master Data'), findsOneWidget);

    // Unauthorized HOD / Teacher / Student module controls are not exposed.
    expect(find.text('HOD Dashboard'), findsNothing);
    expect(find.byKey(const Key('hod-reports-tile')), findsNothing);
    expect(find.text('Attendance'), findsNothing);
    expect(find.byKey(const Key('teacher-reports-tile')), findsNothing);
    expect(find.text('My Attendance'), findsNothing);
    expect(find.text('My Profile'), findsNothing);

    await tester.tap(find.byKey(const Key('admin-students-tile')));
    await tester.pumpAndSettle();

    expect(observer.pushed.last, '/admin/students');
    expect(find.text('Manage Students'), findsOneWidget);
    // Empty student dataset -> placeholder; search bar appears once students exist.
    expect(find.text('No students found. Use + to add one.'), findsOneWidget);
    expect(find.byKey(const Key('add-student')), findsOneWidget);
  });

  testWidgets(
      'HOD home exposes dashboard and reports and navigates to both routes',
      (tester) async {
    final observer = _RouteObserver();
    await _pumpRole(tester, observer, 'HOD');

    expect(find.text('HOD Dashboard'), findsOneWidget);
    expect(find.byKey(const Key('hod-reports-tile')), findsOneWidget);

    // Unauthorized Teacher / Student / Admin controls are not exposed.
    expect(find.text('Attendance'), findsNothing);
    expect(find.byKey(const Key('teacher-reports-tile')), findsNothing);
    expect(find.text('My Attendance'), findsNothing);
    expect(find.text('My Profile'), findsNothing);
    expect(find.byKey(const Key('admin-students-tile')), findsNothing);
    expect(find.text('Manage Students'), findsNothing);
    expect(find.byKey(const Key('admin-master-data-tile')), findsNothing);
    expect(find.text('Master Data'), findsNothing);

    await tester.tap(find.text('HOD Dashboard'));
    await tester.pumpAndSettle();

    expect(observer.pushed.last, '/hod/dashboard');
    expect(find.text('Code: CE'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hod-reports-tile')));
    await tester.pumpAndSettle();

    expect(observer.pushed.last, '/hod/reports');
    expect(find.text('HOD Reports'), findsOneWidget);
  });

  testWidgets(
      'TEACHER home exposes attendance and reports and navigates to both routes',
      (tester) async {
    final observer = _RouteObserver();
    await _pumpRole(tester, observer, 'TEACHER');

    expect(find.text('Attendance'), findsOneWidget);
    expect(find.byKey(const Key('teacher-reports-tile')), findsOneWidget);

    // Unauthorized HOD / Admin / Student controls are not exposed.
    expect(find.text('HOD Dashboard'), findsNothing);
    expect(find.byKey(const Key('hod-reports-tile')), findsNothing);
    expect(find.byKey(const Key('admin-students-tile')), findsNothing);
    expect(find.text('Manage Students'), findsNothing);
    expect(find.byKey(const Key('admin-master-data-tile')), findsNothing);
    expect(find.text('Master Data'), findsNothing);
    expect(find.text('My Attendance'), findsNothing);
    expect(find.text('My Profile'), findsNothing);

    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();

    expect(observer.pushed.last, '/teacher/attendance');
    expect(find.text('Attendance Sessions'), findsOneWidget);
    expect(find.text('No attendance sessions yet.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacher-reports-tile')));
    await tester.pumpAndSettle();

    expect(observer.pushed.last, '/teacher/reports');
    expect(find.text('My Reports'), findsOneWidget);
    expect(
        find.text('No attendance report data for the current filter.'),
        findsOneWidget);
  });

  testWidgets(
      'STUDENT home exposes attendance and profile and navigates to both routes',
      (tester) async {
    final observer = _RouteObserver();
    await _pumpRole(tester, observer, 'STUDENT');

    expect(find.text('My Attendance'), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);

    // Unauthorized Admin / HOD / Teacher controls are not exposed.
    expect(find.byKey(const Key('admin-students-tile')), findsNothing);
    expect(find.text('Manage Students'), findsNothing);
    expect(find.byKey(const Key('admin-master-data-tile')), findsNothing);
    expect(find.text('Master Data'), findsNothing);
    expect(find.text('HOD Dashboard'), findsNothing);
    expect(find.byKey(const Key('hod-reports-tile')), findsNothing);
    expect(find.text('Attendance'), findsNothing);
    expect(find.byKey(const Key('teacher-reports-tile')), findsNothing);

    await tester.tap(find.text('My Attendance'));
    await tester.pumpAndSettle();

    expect(observer.pushed.last, '/student/attendance');
    expect(find.text('My Attendance'), findsOneWidget);
    expect(find.text('No attendance records found.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();

    expect(observer.pushed.last, '/student/profile');
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Student S'), findsOneWidget);
  });
}