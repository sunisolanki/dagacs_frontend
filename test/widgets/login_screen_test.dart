import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/screens/login_screen.dart';
import 'package:dagacs_frontend/widgets/dagacs_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stub AuthRepository that never touches platform plugins, letting the
/// widget tests focus on UI states (loading/validation/error). The real login
/// flow is exercised against the live backend in end-to-end verification.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.onLogin, {this.delay = Duration.zero});
  final AuthResponse Function(String email, String password) onLogin;
  final Duration delay;
  bool persistCalled = false;

  @override
  Future<AuthResponse> login(String email, String password) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return onLogin(email, password);
  }

  @override
  Future<void> persistSession(AuthResponse auth) async {
    persistCalled = true;
  }

  @override
  Future<void> logout() async {}
}

Widget _buildApp(AuthRepository repo, SessionController session) {
  return MaterialApp(
    initialRoute: '/login',
    onGenerateRoute: (settings) {
      switch (settings.name) {
        case '/login':
          return MaterialPageRoute(
              builder: (_) =>
                  LoginScreen(authRepository: repo, session: session));
        case '/home':
          return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('HOME-ROUTE')));
        default:
          return MaterialPageRoute(builder: (_) => const SizedBox());
      }
    },
  );
}

bool _passwordObscured(WidgetTester tester) {
  return tester
      .widget<EditableText>(find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.byType(EditableText),
      ))
      .obscureText;
}

void main() {  testWidgets('shows validation errors for empty fields', (tester) async {
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

  testWidgets('renders email and password fields and welcome heading',
      (tester) async {
    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.text('DAGACS'), findsWidgets);
  });

  testWidgets('password field is obscured by default', (tester) async {
    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    expect(_passwordObscured(tester), isTrue);
  });

  testWidgets('password visibility toggle reveals then hides', (tester) async {
    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    expect(
        _passwordObscured(tester),
        isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
        _passwordObscured(tester),
        isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(
        _passwordObscured(tester),
        isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('empty email shows required while password filled',
      (tester) async {
    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    await tester.enterText(find.byType(TextFormField).at(1), 'Pass1234');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsNothing);
  });

  testWidgets('empty password shows required while email filled',
      (tester) async {
    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Email is required'), findsNothing);
  });

  testWidgets('login button is present using AppPrimaryButton',
      (tester) async {
    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.widgetWithText(AppPrimaryButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('login button shows loading spinner while submitting',
      (tester) async {
    final repo = _FakeAuthRepository(
      (e, p) => const AuthResponse(
          token: 'jwt',
          email: 'admin@dagacs.local',
          fullName: 'Admin',
          role: 'ADMIN'),
      delay: const Duration(seconds: 1),
    );
    final session = SessionController(repo);
    await tester.pumpWidget(_buildApp(repo, session));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@dagacs.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'Admin@123');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('HOME-ROUTE'), findsOneWidget);
  });

  testWidgets('duplicate submit is prevented while loading', (tester) async {
    var calls = 0;
    final repo = _FakeAuthRepository(
      (e, p) {
        calls++;
        return const AuthResponse(
            token: 'jwt',
            email: 'admin@dagacs.local',
            fullName: 'Admin',
            role: 'STUDENT');
      },
      delay: const Duration(seconds: 1),
    );
    final session = SessionController(repo);
    await tester.pumpWidget(_buildApp(repo, session));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@dagacs.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'Admin@123');
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.tap(find.byType(AppPrimaryButton), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('HOME-ROUTE'), findsOneWidget);
  });

  testWidgets('generic error shows fallback message', (tester) async {
    final repo = _FakeAuthRepository((e, p) => throw Exception('boom'));
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@dagacs.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'Admin@123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Login failed. Please try again.'), findsOneWidget);
  });

  testWidgets('successful login persists the session and navigates',
      (tester) async {
    final repo = _FakeAuthRepository((e, p) => const AuthResponse(
        token: 'jwt', email: 'admin@dagacs.local',
        fullName: 'Admin', role: 'ADMIN'));
    final session = SessionController(repo);
    await tester.pumpWidget(_buildApp(repo, session));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@dagacs.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'Admin@123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(repo.persistCalled, isTrue);
    expect(session.isAuthenticated, isTrue);
    expect(session.role, 'ADMIN');
    expect(find.text('HOME-ROUTE'), findsOneWidget);
  });

  testWidgets('no overflow at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    expect(tester.takeException(), isNull);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('no overflow at 390px width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    expect(tester.takeException(), isNull);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('tablet layout renders without overflow at 768px',
      (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('desktop layout shows side-by-side brand panel at 1280px',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeAuthRepository((e, p) => throw UnimplementedError());
    final session = SessionController(repo);
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(authRepository: repo, session: session)));

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.textContaining('Department Attendance Governance'),
        findsOneWidget);
  });

  testWidgets('keyboard submit on password field logs in', (tester) async {
    final repo = _FakeAuthRepository((e, p) => const AuthResponse(
        token: 'jwt', email: 'admin@dagacs.local',
        fullName: 'Admin', role: 'ADMIN'));
    final session = SessionController(repo);
    await tester.pumpWidget(_buildApp(repo, session));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@dagacs.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'Admin@123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(session.role, 'ADMIN');
    expect(find.text('HOME-ROUTE'), findsOneWidget);
  });
}
