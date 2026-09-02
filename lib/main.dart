import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/app_shell.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginScreen());
          case '/admin':
          case '/hod':
          case '/teacher':
          case '/student':
            return MaterialPageRoute(builder: (_) => AppShell(navigatorKey: navigatorKey));
          default:
            return MaterialPageRoute(builder: (_) => LoginScreen());
        }
      },
    );
  }
}