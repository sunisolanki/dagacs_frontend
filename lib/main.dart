import 'package:flutter/material.dart';

import 'core/session/session_controller.dart';
import 'network/api_client.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/hod_repository.dart';
import 'repositories/master_data_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/student_profile_repository.dart';
import 'repositories/student_management_repository.dart';
import 'screens/attendance_session_list_screen.dart';
import 'screens/create_session_screen.dart';
import 'screens/hod_dashboard_screen.dart';
import 'screens/hod_reports_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mark_attendance_screen.dart';
import 'screens/master_data_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/student_attendance_screen.dart';
import 'screens/student_profile_screen.dart';
import 'screens/student_management_screen.dart';
import 'screens/teacher_reports_screen.dart';

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
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
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
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A73E8),
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
      ),
      navigatorKey: navigatorKey,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(
                builder: (_) => SplashScreen(session: AppDependencies.session));
          case '/login':
            return MaterialPageRoute(
                builder: (_) => LoginScreen(
                    authRepository: AppDependencies.authRepository,
                    session: AppDependencies.session));
          case '/home':
            return MaterialPageRoute(
                builder: (_) => HomeScreen(
                    session: AppDependencies.session,
                    masterDataRepository:
                        AppDependencies.masterDataRepository));
          case '/master-data':
            return MaterialPageRoute(
                builder: (_) => MasterDataScreen(
                    repository: AppDependencies.masterDataRepository,
                    session: AppDependencies.session));
          case '/teacher/attendance':
            return MaterialPageRoute(
                builder: (_) => AttendanceSessionListScreen(
                    attendanceRepository:
                        AppDependencies.attendanceRepository));
          case '/teacher/attendance/create':
            return MaterialPageRoute(
                builder: (_) => CreateSessionScreen(
                    attendanceRepository:
                        AppDependencies.attendanceRepository));
          case '/teacher/attendance/mark':
            final sessionId = settings.arguments as int;
            return MaterialPageRoute(
                builder: (_) => MarkAttendanceScreen(
                    sessionId: sessionId,
                    attendanceRepository:
                        AppDependencies.attendanceRepository));
          case '/student/attendance':
            return MaterialPageRoute(
                builder: (_) => StudentAttendanceScreen(
                    attendanceRepository:
                        AppDependencies.attendanceRepository));
          case '/student/profile':
            return MaterialPageRoute(
                builder: (_) => StudentProfileScreen(
                    profileRepository:
                        AppDependencies.studentProfileRepository));
          case '/hod/dashboard':
            return MaterialPageRoute(
                builder: (_) => HodDashboardScreen(
                    hodRepository: AppDependencies.hodRepository));
          case '/hod/reports':
            return MaterialPageRoute(
                builder: (_) => HodReportsScreen(
                    hodRepository: AppDependencies.hodRepository,
                    reportRepository: AppDependencies.reportRepository));
          case '/teacher/reports':
            return MaterialPageRoute(
                builder: (_) => TeacherReportsScreen(
                    reportRepository: AppDependencies.reportRepository));
          case '/admin/students':
            return MaterialPageRoute(
                builder: (_) => StudentManagementScreen(
                    repository: AppDependencies.studentManagementRepository,
                    masterDataRepository:
                        AppDependencies.masterDataRepository));
          default:
            return MaterialPageRoute(builder: (_) => const SizedBox());
        }
      },
    );
  }
}
