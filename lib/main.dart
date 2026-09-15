import 'package:flutter/material.dart';

import 'core/navigation/navigator.dart';
import 'core/theme/dagacs_theme.dart';
import 'core/session/session_controller.dart';
import 'models/teacher_assignment.dart';
import 'network/api_client.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/hod_repository.dart';
import 'repositories/master_data_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/student_profile_repository.dart';
import 'repositories/student_management_repository.dart';
import 'repositories/teacher_management_repository.dart';
import 'repositories/teacher_repository.dart';
import 'screens/attendance_session_list_screen.dart';
import 'screens/create_session_screen.dart';
import 'screens/hod_dashboard_screen.dart';
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
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DAGACSApp());
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
                        AppDependencies.masterDataRepository));
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
                        AppDependencies.attendanceRepository));
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
                    teacherRepository: AppDependencies.teacherRepository));
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
                        AppDependencies.attendanceRepository));
           case AppRoutes.studentProfile:
             return MaterialPageRoute(
                 builder: (_) => StudentProfileScreen(
                     profileRepository:
                         AppDependencies.studentProfileRepository));
           case AppRoutes.studentChangePassword:
             return MaterialPageRoute(
                 builder: (_) => ChangePasswordScreen(
                     session: AppDependencies.session,
                     repository:
                         AppDependencies.studentManagementRepository));
           case AppRoutes.hodDashboard:
            return MaterialPageRoute(
                builder: (_) => HodDashboardScreen(
                    hodRepository: AppDependencies.hodRepository));
          case AppRoutes.hodReports:
            return MaterialPageRoute(
                builder: (_) => HodReportsScreen(
                    hodRepository: AppDependencies.hodRepository,
                    reportRepository: AppDependencies.reportRepository));
          case AppRoutes.teacherReports:
            return MaterialPageRoute(
                builder: (_) => TeacherReportsScreen(
                    reportRepository: AppDependencies.reportRepository,
                    teacherRepository: AppDependencies.teacherRepository));
          case AppRoutes.teacherStudentWise:
            return MaterialPageRoute(
                builder: (_) => StudentWiseReportScreen(
                    reportRepository: AppDependencies.reportRepository,
                    teacherRepository: AppDependencies.teacherRepository));
          case AppRoutes.adminStudents:
            return MaterialPageRoute(
                builder: (_) => StudentManagementScreen(
                    repository: AppDependencies.studentManagementRepository,
                    masterDataRepository:
                        AppDependencies.masterDataRepository));
          default:
            return MaterialPageRoute(builder: (_) => const NotFoundScreen());
        }
      },
    );
  }
}
