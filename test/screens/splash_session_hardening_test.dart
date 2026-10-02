import 'dart:async';

import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/screens/splash_screen.dart';
import 'package:dagacs_frontend/services/token_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [SessionController] whose behaviour is fully scripted, so the session
/// lifecycle can be tested without touching the platform secure store.
class _ScriptedSession extends SessionController {
  _ScriptedSession(super.repository);

  /// When true, restoration hangs until the caller's budget expires.
  bool hang = false;
  Object? throwOnRestore;
  /// What `isAuthenticated` should be once restoration succeeds. Applied
  /// directly so no storage read is involved.
  bool authenticatedAfterRestore = false;
  int restoreCalls = 0;
  int clearCalls = 0;

  @override
  Future<void> restoreSession() async {
    restoreCalls++;
    if (throwOnRestore != null) {
      throw throwOnRestore!;
    }
    if (hang) {
      await Completer<void>().future; // never completes
    }
    if (authenticatedAfterRestore) {
      establishSession('STUDENT');
    } else {
      // Mirror the real controller's "no token means no session" outcome,
      // through its own public API rather than reaching for private state.
      await clearSession();
    }
  }

  @override
  Future<void> clearSession() async {
    clearCalls++;
    await super.clearSession();
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient());
  int logoutCalls = 0;
  bool throwOnLogout = false;

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (throwOnLogout) {
      throw StateError('storage unavailable');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenService.clearSession completeness', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('removes every persisted session key, not just some', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'HOD');
      await prefs.setString('user_email', 'hod@dagacs.local');
      await prefs.setString('user_full_name', 'HOD User');
      await prefs.setBool('must_change_password', true);
      // The JWT lives in the platform secure store, which is unavailable in a
      // unit test; the metadata keys are what can be asserted here.

      await TokenService.clearSession();

      expect(prefs.getString('user_role'), isNull,
          reason: 'a logout must not leave a role behind');
      expect(prefs.getString('user_email'), isNull);
      expect(prefs.getString('user_full_name'), isNull);
      expect(prefs.getBool('must_change_password'), isNull,
          reason: 'Phase 5.2: this key used to survive clearSession, so a '
              'cleared session was not fully cleared');
    });

    test('a stale forced-change flag cannot outlive a logout', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('must_change_password', true);
      await TokenService.clearSession();
      expect(prefs.containsKey('must_change_password'), isFalse);
    });

    test('is safe to call when nothing is stored', () async {
      await expectLater(TokenService.clearSession(), completes);
    });
  });

  group('SessionController.clearSession', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('resets every field it exposes', () async {
      final repository = _FakeAuthRepository();
      final session = SessionController(repository);
      session.establishSession('HOD',
          email: 'hod@dagacs.local', fullName: 'HOD User', mustChangePassword: true);
      expect(session.isAuthenticated, isTrue);

      await session.clearSession();

      expect(session.isAuthenticated, isFalse);
      expect(session.role, 'STUDENT');
      expect(session.email, isNull);
      expect(session.fullName, isNull);
      expect(session.mustChangePassword, isFalse);
      expect(repository.logoutCalls, 1);
    });

    test('still signs the user out when storage throws', () async {
      // Phase 5.2: a storage failure must not leave a "logged out" user holding
      // a live screen. The in-memory reset is what the UI renders from.
      final repository = _FakeAuthRepository()..throwOnLogout = true;
      final session = SessionController(repository);
      session.establishSession('ADMIN', email: 'admin@dagacs.local');

      await expectLater(session.clearSession(), throwsStateError);

      expect(session.isAuthenticated, isFalse,
          reason: 'the reset is applied before storage is touched');
      expect(session.email, isNull);
    });

    test('logout returns the user to an unauthenticated state', () async {
      final repository = _FakeAuthRepository();
      final session = SessionController(repository);
      session.establishSession('TEACHER', email: 'teacher@dagacs.local');
      await session.clearSession();
      // The decision the splash and home gate make.
      expect(session.isAuthenticated, isFalse);
    });
  });

  group('SplashScreen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget host(SessionController session, {Duration? timeout}) => MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => SplashScreen(session: session, restoreTimeout: timeout),
            '/home': (context) => const Scaffold(body: Text('HOME-ROUTE')),
            '/login': (context) => const Scaffold(body: Text('LOGIN-ROUTE')),
          },
        );

    testWidgets('an authenticated session routes to home', (tester) async {
      final session =
          _ScriptedSession(_FakeAuthRepository())..authenticatedAfterRestore = true;

      await tester.pumpWidget(host(session, timeout: const Duration(seconds: 1)));
      await tester.pumpAndSettle();

      expect(find.text('HOME-ROUTE'), findsOneWidget);
    });

    testWidgets('no session routes to login', (tester) async {
      final session = _ScriptedSession(_FakeAuthRepository());

      await tester.pumpWidget(host(session, timeout: const Duration(seconds: 1)));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN-ROUTE'), findsOneWidget);
    });

    testWidgets('a wedged restore never strands the user on a spinner',
        (tester) async {
      // Phase 5.2: restoreSession() has no completion guarantee, so the splash
      // must be bounded. Without the bound this test would time out, which is
      // exactly the production symptom being removed.
      final session = _ScriptedSession(_FakeAuthRepository())..hang = true;

      await tester.pumpWidget(host(session, timeout: const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'the splash must not spin forever');
      expect(find.byKey(const Key('splash-restore-failed')), findsOneWidget);
    });

    testWidgets('an unverifiable session fails closed to login', (tester) async {
      // A restore that throws must not be treated as a successful restore of an
      // authenticated user, and must not leave the user on the splash.
      final session = _ScriptedSession(_FakeAuthRepository())
        ..throwOnRestore = StateError('secure store unavailable');

      await tester.pumpWidget(host(session, timeout: const Duration(seconds: 1)));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN-ROUTE'), findsOneWidget);
      expect(session.clearCalls, greaterThan(0),
          reason: 'the unreadable credential must be discarded, not reused');
    });

    testWidgets('the failure screen offers a way forward', (tester) async {
      final session = _ScriptedSession(_FakeAuthRepository())..hang = true;
      await tester.pumpWidget(host(session, timeout: const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('splash-retry')), findsOneWidget);
      expect(find.byKey(const Key('splash-go-to-login')), findsOneWidget);

      // The explicit escape hatch reaches login even if Retry keeps failing.
      await tester.tap(find.byKey(const Key('splash-go-to-login')));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN-ROUTE'), findsOneWidget);
    });

    testWidgets('Retry re-attempts restoration', (tester) async {
      final session = _ScriptedSession(_FakeAuthRepository())..hang = true;
      await tester.pumpWidget(host(session, timeout: const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      final attemptsWhileHung = session.restoreCalls;

      await tester.tap(find.byKey(const Key('splash-retry')));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(session.restoreCalls, greaterThan(attemptsWhileHung),
          reason: 'Retry must actually retry');
    });
  });
}
