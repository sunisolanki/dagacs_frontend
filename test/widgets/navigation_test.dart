import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stub repo that never touches platform plugins.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

/// Plugin-free stand-in for SplashScreen's routing decision: it renders the
/// Login screen when unauthenticated and Home when authenticated. SplashScreen
/// itself only computes the same `session.isAuthenticated` value (which is
/// driven by plugin-backed restore and verified end-to-end separately).
class _Root extends StatelessWidget {
  const _Root({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return session.isAuthenticated
            ? const Scaffold(body: Center(child: Text('HOME-ROUTE')))
            : LoginScreen(
                authRepository: _FakeAuthRepository(), session: session);
      },
    );
  }
}

void main() {
  testWidgets('unauthenticated user sees login screen', (tester) async {
    final session = SessionController(_FakeAuthRepository());
    await tester.pumpWidget(MaterialApp(home: _Root(session: session)));

    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('HOME-ROUTE'), findsNothing);
  });

  testWidgets('authenticated user sees home screen', (tester) async {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('ADMIN', email: 'admin@dagacs.local');

    await tester.pumpWidget(MaterialApp(home: _Root(session: session)));

    expect(find.text('HOME-ROUTE'), findsOneWidget);
    expect(session.isAuthenticated, isTrue);
  });

  testWidgets('logout returns unauthenticated user to login', (tester) async {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('STUDENT');

    await tester.pumpWidget(MaterialApp(home: _Root(session: session)));
    expect(find.text('HOME-ROUTE'), findsOneWidget);

    await session.clearSession();
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsWidgets);
    expect(session.isAuthenticated, isFalse);
  });
}
