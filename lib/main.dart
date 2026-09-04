import 'package:flutter/material.dart';

import 'core/session/session_controller.dart';
import 'network/api_client.dart';
import 'repositories/auth_repository.dart';
import 'repositories/master_data_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/master_data_screen.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Lightweight shared dependencies (no external DI package).
class AppDependencies {
  AppDependencies._();

  static final ApiClient apiClient = ApiClient(onUnauthorized: () {
    // Session expired: force back to login once navigation is available.
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
  });

  static final AuthRepository authRepository = AuthRepository(apiClient);
  static final MasterDataRepository masterDataRepository =
      MasterDataRepository(apiClient);
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
          default:
            return MaterialPageRoute(builder: (_) => const SizedBox());
        }
      },
    );
  }
}
