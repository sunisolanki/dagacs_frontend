import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';

/// Shows during startup while the persisted session is being restored.
/// Routes to /login (unauthenticated) or /home (authenticated).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await widget.session.restoreSession();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
        context, widget.session.isAuthenticated ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield, size: 96, color: Color(0xFF1A73E8)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
