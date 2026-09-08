import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stub AuthRepository that never touches platform plugins, letting the
/// widget tests focus on UI states (loading/validation/error). The real login
/// flow is exercised against the live backend in end-to-end verification.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.onLogin);
  final AuthResponse Function(String email, String password) onLogin;

  @override
  Future<AuthResponse> login(String email, String password) async =>
      onLogin(email, password);

  @override
  Future<void> persistSession(AuthResponse auth) async {}

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('shows validation errors for empty fields', (tester) async {
    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows network error on failure', (tester) async {
    final repo = _FakeAuthRepository(
        (e, p) => throw const ApiException.network());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to connect'), findsOneWidget);
  });

  testWidgets('shows invalid credentials message on 401', (tester) async {
    final repo = _FakeAuthRepository((e, p) {
      throw const ApiException.unauthorized();
    });
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@dagacs.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'WrongPass1');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('successful login establishes session and routes to home',
      (tester) async {
    final repo = _FakeAuthRepository((e, p) => const AuthResponse(
        token: 'jwt', email: 'admin@dagacs.local',
        fullName: 'Admin', role: 'ADMIN'));
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(
                builder: (_) => LoginScreen(authRepository: repo,
                    session: session));
          case '/home':
            return MaterialPageRoute(
                builder: (_) => Scaffold(body: Text('HOME-ROUTE')));
          default:
            return MaterialPageRoute(builder: (_) => const SizedBox());
        }
      },
    ));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@dagacs.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'Admin@123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('HOME-ROUTE'), findsOneWidget);
    expect(session.isAuthenticated, isTrue);
    expect(session.role, 'ADMIN');
  });
}
