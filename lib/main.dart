import 'package:flutter/material.dart';

import 'core/context/hod_academic_context.dart';
import 'core/navigation/navigator.dart';
import 'core/theme/dagacs_theme.dart';
import 'core/session/session_controller.dart';
import 'models/teacher_assignment.dart';
import 'network/api_client.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/hod_attendance_repository.dart';
import 'repositories/hod_hierarchy_repository.dart';
import 'repositories/hod_repository.dart';
import 'repositories/master_data_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/student_profile_repository.dart';
import 'repositories/student_management_repository.dart';
import 'repositories/teacher_management_repository.dart';
import 'repositories/teacher_repository.dart';
import 'services/hod_hierarchy_loader.dart';
import 'screens/attendance_session_list_screen.dart';
import 'screens/create_session_screen.dart';
import 'screens/hod/hod_attendance_matrix_screen.dart';
import 'screens/hod/hod_audit_logs_screen.dart';
import 'screens/hod/hod_low_attendance_screen.dart';
import 'screens/hod/hod_overview_screen.dart';
import 'screens/hod/hod_rollups_screen.dart';
import 'screens/hod/hod_sections_screen.dart';
import 'screens/hod/hod_student_detail_screen.dart';
import 'screens/hod/hod_students_screen.dart';
import 'screens/hod/hod_structure_screen.dart';
import 'screens/hod/hod_subject_detail_screen.dart';
import 'screens/hod/hod_subjects_screen.dart';
import 'screens/hod_reports_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mark_attendance_screen.dart';
import 'screens/master_data/academic_session_list_screen.dart';
import 'screens/master_data/assignment_list_screen.dart';
import 'screens/master_data/batch_list_screen.dart';
import 'screens/master_data/department_list_screen.dart';
import 'screens/master_data/program_list_screen.dart';
import 'screens/master_data/section_list_screen.dart';
import 'screens/master_data/semester_list_screen.dart';
import 'screens/master_data/subject_list_screen.dart';
import 'screens/master_data/subject_offering_list_screen.dart';
import 'screens/master_data/teacher_list_screen.dart';
import 'screens/master_data_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/student_attendance_screen.dart';
import 'screens/student_profile_screen.dart';
import 'screens/student_management_screen.dart';
import 'screens/teacher_classes_screen.dart';
import 'screens/teacher_reports_screen.dart';
import 'screens/student_wise_report_screen.dart';
import 'screens/change_password_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Lightweight shared dependencies (no external DI package).
class AppDependencies {
  AppDependencies._();

  static final ApiClient apiClient = ApiClient(onUnauthorized: () {
    // Session expired: clear the persisted session and force back to login
    // once navigation is available (M7.5 lifecycle hardening). The backend
    // remains the JWT authority; this only resets local state.
    AppDependencies.session.clearSession();
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  });

  static final AuthRepository authRepository = AuthRepository(apiClient);
  static final MasterDataRepository masterDataRepository =
      MasterDataRepository(apiClient);
  static final AttendanceRepository attendanceRepository =
      AttendanceRepository(apiClient);
  static final HodRepository hodRepository = HodRepository(apiClient);
  /// Phase 3 HOD attendance intelligence (overview, matrix, detail, low
  /// attendance) and the matrix Excel/PDF export.
  static final HodAttendanceRepository hodAttendanceRepository =
      HodAttendanceRepository(apiClient);
  static final ReportRepository reportRepository =
      ReportRepository(apiClient);
  static final StudentProfileRepository studentProfileRepository =
      StudentProfileRepository(apiClient);
  static final StudentManagementRepository studentManagementRepository =
      StudentManagementRepository(apiClient);
  static final TeacherRepository teacherRepository =
      TeacherRepository(apiClient);
  static final TeacherManagementRepository teacherManagementRepository =
      TeacherManagementRepository(apiClient);
  static final SessionController session =
      SessionController(authRepository);

  /// Shared HOD academic context. A single instance keeps the Academic Session
  /// -> Program -> Semester -> Section -> Subject selection (and the date
  /// range) alive across HOD route navigation.
  static final HodAcademicContext hodContext = HodAcademicContext();

  /// Loads the department-scoped academic hierarchy once and caches it. Shared
  /// by every HOD route so re-entering a screen never refetches the root.
  static final HodHierarchyLoader hodHierarchyLoader = HodHierarchyLoader(
    repository: HodHierarchyRepository(apiClient),
    context: hodContext,
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DAGACSApp());
}

/// Opens one student's attendance detail in the current academic context.
///
/// The id always originates from a tapped row, and the selected academic context
/// travels with the screen, so the detail can never describe a different
/// semester or section than the one the HOD is reviewing.
void _openStudentDetail(int studentId) {
  navigatorKey.currentState?.pushNamed(AppRoutes.hodStudentDetail, arguments: studentId);
}

/// Opens one subject's attendance detail in the current academic context.
void _openSubjectDetail(int subjectId) {
  navigatorKey.currentState?.pushNamed(AppRoutes.hodSubjectDetail, arguments: subjectId);
}

class DAGACSApp extends StatelessWidget {
  const DAGACSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAGACS',
      debugShowCheckedModeBanner: false,
      theme: buildDagacsTheme(),
      navigatorKey: navigatorKey,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return MaterialPageRoute(
                builder: (_) => SplashScreen(session: AppDependencies.session));
          case AppRoutes.login:
            return MaterialPageRoute(
                builder: (_) => LoginScreen(
                    authRepository: AppDependencies.authRepository,
                    session: AppDependencies.session));
          case AppRoutes.home:
            return MaterialPageRoute(
                builder: (_) => HomeScreen(
                    session: AppDependencies.session,
                    masterDataRepository:
                        AppDependencies.masterDataRepository,
                    // Student home renders the live attendance dashboard; the
                    // parameter is nullable so a host without the repository
                    // simply falls back to the plain tile list.
                    attendanceRepository:
                        AppDependencies.attendanceRepository,
                    // Teacher home renders the data-backed teacher dashboard.
                    teacherRepository: AppDependencies.teacherRepository));
          case AppRoutes.masterData:
            return MaterialPageRoute(
                builder: (_) => MasterDataScreen(
                    repository: AppDependencies.masterDataRepository,
                    teacherManagementRepository:
                        AppDependencies.teacherManagementRepository,
                    session: AppDependencies.session));
          case AppRoutes.masterDataDepartments:
            return MaterialPageRoute(
                builder: (_) => DepartmentListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataPrograms:
            return MaterialPageRoute(
                builder: (_) => ProgramListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataAcademicSessions:
            return MaterialPageRoute(
                builder: (_) => AcademicSessionListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataSemesters:
            return MaterialPageRoute(
                builder: (_) => SemesterListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataBatches:
            return MaterialPageRoute(
                builder: (_) => BatchListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataSections:
            return MaterialPageRoute(
                builder: (_) => SectionListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataSubjects:
            return MaterialPageRoute(
                builder: (_) => SubjectListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataSubjectOfferings:
            return MaterialPageRoute(
                builder: (_) => SubjectOfferingListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataTeacherAssignments:
            return MaterialPageRoute(
                builder: (_) => TeacherAssignmentListScreen(
                    repository: AppDependencies.masterDataRepository));
          case AppRoutes.masterDataTeachers:
            return MaterialPageRoute(
                builder: (_) => TeacherListScreen(
                    repository: AppDependencies.teacherManagementRepository,
                    masterDataRepository:
                        AppDependencies.masterDataRepository));
          case AppRoutes.teacherAttendance:
            return MaterialPageRoute(
                builder: (_) => AttendanceSessionListScreen(
                    attendanceRepository:
                        AppDependencies.attendanceRepository,
                    session: AppDependencies.session));
          case AppRoutes.createSession:
            final assignment = settings.arguments;
            return MaterialPageRoute(
                builder: (_) => CreateSessionScreen(
                    attendanceRepository:
                        AppDependencies.attendanceRepository,
                    teacherRepository: AppDependencies.teacherRepository,
                    preselectedAssignment: assignment is TeacherAssignment
                        ? assignment
                        : null));
          case AppRoutes.teacherClasses:
            return MaterialPageRoute(
                builder: (_) => TeacherClassesScreen(
                    teacherRepository: AppDependencies.teacherRepository,
                    session: AppDependencies.session));
          case AppRoutes.markAttendance:
            final sessionId = settings.arguments is int
                ? settings.arguments as int
                : null;
            if (sessionId == null) {
              return MaterialPageRoute(
                  builder: (_) => const NotFoundScreen());
            }
            return MaterialPageRoute(
                builder: (_) => MarkAttendanceScreen(
                    sessionId: sessionId,
                    attendanceRepository:
                        AppDependencies.attendanceRepository));
          case AppRoutes.studentAttendance:
            return MaterialPageRoute(
builder: (_) => StudentAttendanceScreen(
                    attendanceRepository:
                        AppDependencies.attendanceRepository,
                    session: AppDependencies.session));
           case AppRoutes.studentProfile:
             return MaterialPageRoute(
                builder: (_) => StudentProfileScreen(
                    profileRepository:
                        AppDependencies.studentProfileRepository,
                    session: AppDependencies.session));
           case AppRoutes.studentChangePassword:
             return MaterialPageRoute(
                 builder: (_) => ChangePasswordScreen(
                     session: AppDependencies.session,
                     repository:
                         AppDependencies.studentManagementRepository));
           case AppRoutes.hodDashboard:
            return MaterialPageRoute(
                builder: (_) => HodOverviewScreen(
                    hodRepository: AppDependencies.hodRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader,
                    attendanceRepository:
                        AppDependencies.hodAttendanceRepository,
                    onOpenStudent: _openStudentDetail,
                    onOpenSubject: _openSubjectDetail));
           case AppRoutes.hodStructure:
            return MaterialPageRoute(
                builder: (_) => HodStructureScreen(
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext));
           case AppRoutes.hodSections:
            return MaterialPageRoute(
                builder: (_) => HodSectionsScreen(
                    hodRepository: AppDependencies.hodRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader));
           case AppRoutes.hodSubjects:
            return MaterialPageRoute(
                builder: (_) => HodSubjectsScreen(
                    hodRepository: AppDependencies.hodRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader,
                    attendanceRepository:
                        AppDependencies.hodAttendanceRepository,
                    onOpenSubject: _openSubjectDetail));
           case AppRoutes.hodStudents:
            return MaterialPageRoute(
                builder: (_) => HodStudentsScreen(
                    hodRepository: AppDependencies.hodRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader,
                    attendanceRepository:
                        AppDependencies.hodAttendanceRepository,
                    onOpenStudent: _openStudentDetail));
           case AppRoutes.hodLowAttendance:
            return MaterialPageRoute(
                builder: (_) => HodLowAttendanceScreen(
                    hodRepository: AppDependencies.hodRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader,
                    attendanceRepository:
                        AppDependencies.hodAttendanceRepository,
                    onOpenStudent: _openStudentDetail));
           case AppRoutes.hodRollups:
            return MaterialPageRoute(
                builder: (_) => HodRollupsScreen(
                    hodRepository: AppDependencies.hodRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext));
           case AppRoutes.hodAuditLogs:
            return MaterialPageRoute(
                builder: (_) => HodAuditLogsScreen(
                    hodRepository: AppDependencies.hodRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext));
           case AppRoutes.hodAttendanceMatrix:
            return MaterialPageRoute(
                builder: (_) => HodAttendanceMatrixScreen(
                    repository: AppDependencies.hodAttendanceRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader));
           case AppRoutes.hodStudentDetail:
            // The id always originates from a tapped row; the server still
            // proves it belongs to the selected context before any query.
            final studentId = settings.arguments is int
                ? settings.arguments as int
                : null;
            if (studentId == null) {
              return MaterialPageRoute(builder: (_) => const NotFoundScreen());
            }
            return MaterialPageRoute(
                builder: (_) => HodStudentDetailScreen(
                    repository: AppDependencies.hodAttendanceRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader,
                    studentId: studentId));
           case AppRoutes.hodSubjectDetail:
            final subjectId = settings.arguments is int
                ? settings.arguments as int
                : null;
            if (subjectId == null) {
              return MaterialPageRoute(builder: (_) => const NotFoundScreen());
            }
            return MaterialPageRoute(
                builder: (_) => HodSubjectDetailScreen(
                    repository: AppDependencies.hodAttendanceRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader,
                    subjectId: subjectId));
           case AppRoutes.hodReports:
            return MaterialPageRoute(
                builder: (_) => HodReportsScreen(
                    hodRepository: AppDependencies.hodRepository,
                    reportRepository: AppDependencies.reportRepository,
                    attendanceRepository:
                        AppDependencies.hodAttendanceRepository,
                    session: AppDependencies.session,
                    academicContext: AppDependencies.hodContext,
                    hierarchyLoader: AppDependencies.hodHierarchyLoader,
                    onOpenStudent: _openStudentDetail,
                    onOpenSubject: _openSubjectDetail));
          case AppRoutes.teacherReports:
            return MaterialPageRoute(
                builder: (_) => TeacherReportsScreen(
                    reportRepository: AppDependencies.reportRepository,
                    teacherRepository: AppDependencies.teacherRepository,
                    session: AppDependencies.session));
          case AppRoutes.teacherStudentWise:
            return MaterialPageRoute(
                builder: (_) => StudentWiseReportScreen(
                    reportRepository: AppDependencies.reportRepository,
                    teacherRepository: AppDependencies.teacherRepository,
                    session: AppDependencies.session));
          case AppRoutes.adminStudents:
            return MaterialPageRoute(
                builder: (_) => StudentManagementScreen(
                    repository: AppDependencies.studentManagementRepository,
                    masterDataRepository:
                        AppDependencies.masterDataRepository,
                    session: AppDependencies.session));
          default:
            return MaterialPageRoute(builder: (_) => const NotFoundScreen());
        }
      },
    );
  }
}
