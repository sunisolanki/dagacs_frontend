import 'dart:convert';

import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/student_management_repository.dart';
import 'package:dagacs_frontend/screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _MockClient extends http.BaseClient {
  _MockClient(this._handler);
  final http.Response Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final resp = _handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(resp.body)),
      resp.statusCode,
      headers: resp.headers,
    );
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

class _FakeStudentManagementRepository extends StudentManagementRepository {
  _FakeStudentManagementRepository({this.onChangePassword})
      : super(ApiClient());
  final Future<void> Function(String current, String next)? onChangePassword;
  bool changeCalled = false;
  String? capturedCurrent;
  String? capturedNew;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    changeCalled = true;
    capturedCurrent = currentPassword;
    capturedNew = newPassword;
    final handler = onChangePassword;
    if (handler != null) {
      await handler(currentPassword, newPassword);
    }
  }
}

Widget _buildApp(
    SessionController session, StudentManagementRepository repository) {
  return MaterialApp(
    initialRoute: '/change-password',
    onGenerateRoute: (settings) {
      switch (settings.name) {
        case '/home':
          return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('HOME-ROUTE')));
        case '/change-password':
          return MaterialPageRoute(
              builder: (_) =>
                  ChangePasswordScreen(session: session, repository: repository));
        default:
          return MaterialPageRoute(builder: (_) => const SizedBox());
      }
    },
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders password fields and update button', (tester) async {
    final repo = _FakeStudentManagementRepository();
    final session = SessionController(_FakeAuthRepository());
    await tester.pumpWidget(_buildApp(session, repo));

    expect(find.text('Change Your Password'), findsOneWidget);
    expect(find.byKey(const Key('field-current-password')), findsOneWidget);
    expect(find.byKey(const Key('field-new-password')), findsOneWidget);
    expect(find.byKey(const Key('field-confirm-password')), findsOneWidget);
    expect(find.text('Update Password'), findsOneWidget);
  });

  testWidgets('validates required and minimal length', (tester) async {
    final repo = _FakeStudentManagementRepository();
    final session = SessionController(_FakeAuthRepository());
    await tester.pumpWidget(MaterialApp(
        home: ChangePasswordScreen(
            session: session, repository: repo)));

    await tester.ensureVisible(find.text('Update Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(find.text('Current password is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('field-current-password')), 'Temp#Old2026');
    await tester.enterText(
        find.byKey(const Key('field-new-password')), 'short');
    await tester.enterText(
        find.byKey(const Key('field-confirm-password')), 'short');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('blocks mismatched passwords', (tester) async {
    final repo = _FakeStudentManagementRepository();
    final session = SessionController(_FakeAuthRepository());
    await tester.pumpWidget(MaterialApp(
        home: ChangePasswordScreen(
            session: session, repository: repo)));

    await tester.enterText(
        find.byKey(const Key('field-current-password')), 'Temp#Old2026');
    await tester.enterText(
        find.byKey(const Key('field-new-password')), 'NewPass#2026');
    await tester.enterText(
        find.byKey(const Key('field-confirm-password')), 'Different#99');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(repo.changeCalled, isFalse);
  });

  testWidgets('successful change keeps session and routes to student home',
      (tester) async {
    final repo = _FakeStudentManagementRepository();
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('STUDENT',
        email: 's@dagacs.local',
        fullName: 'Student',
        mustChangePassword: true);

    await tester.pumpWidget(_buildApp(session, repo));

    await tester.enterText(
        find.byKey(const Key('field-current-password')), 'Temp#Old2026');
    await tester.enterText(
        find.byKey(const Key('field-new-password')), 'NewPass#2026');
    await tester.enterText(
        find.byKey(const Key('field-confirm-password')), 'NewPass#2026');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(repo.changeCalled, isTrue);
    expect(repo.capturedCurrent, 'Temp#Old2026');
    expect(repo.capturedNew, 'NewPass#2026');
    // session is kept - no logout
    expect(session.isAuthenticated, isTrue);
    expect(session.mustChangePassword, isFalse);
    expect(find.text('HOME-ROUTE'), findsOneWidget);
  });

  testWidgets('server error surfaces as an inline message', (tester) async {
    final repo = _FakeStudentManagementRepository(
        onChangePassword: (c, n) async =>
            throw const ApiException(400, 'Current password is incorrect'));
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('STUDENT',
        email: 's@dagacs.local', mustChangePassword: true);
    await tester.pumpWidget(_buildApp(session, repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('field-current-password')), 'Wrong#Pass1');
    await tester.enterText(
        find.byKey(const Key('field-new-password')), 'NewPass#2026');
    await tester.enterText(
        find.byKey(const Key('field-confirm-password')), 'NewPass#2026');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(session.mustChangePassword, isTrue);
    expect(repo.changeCalled, isTrue);
  });

  testWidgets(
      'successful empty-body 200 from real repository shows no error '
      'and navigates to student home', (tester) async {
    final client = ApiClient(
      baseUrl: 'http://test.local/api',
      tokenProvider: () async => 'student-token',
      httpClient: _MockClient((req) {
        return http.Response('', 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    final repo = StudentManagementRepository(client);
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('STUDENT',
        email: 's@dagacs.local',
        fullName: 'Student',
        mustChangePassword: true);

    await tester.pumpWidget(_buildApp(session, repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('field-current-password')), 'Temp#Old2026');
    await tester.enterText(
        find.byKey(const Key('field-new-password')), 'NewPass#2026');
    await tester.enterText(
        find.byKey(const Key('field-confirm-password')), 'NewPass#2026');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Please try again.'), findsNothing);
    expect(find.text('HOME-ROUTE'), findsOneWidget);
    expect(session.mustChangePassword, isFalse);
    expect(session.isAuthenticated, isTrue);
  });

  testWidgets(
      'non-2xx error from real repository displays backend error message '
      'and does not navigate', (tester) async {
    final client = ApiClient(
      baseUrl: 'http://test.local/api',
      tokenProvider: () async => 'student-token',
      httpClient: _MockClient((req) {
        return http.Response(
            '{"message":"Current password is incorrect"}', 400,
            headers: {'content-type': 'application/json'});
      }),
    );
    final repo = StudentManagementRepository(client);
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('STUDENT',
        email: 's@dagacs.local', mustChangePassword: true);

    await tester.pumpWidget(_buildApp(session, repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('field-current-password')), 'Wrong#Pass1');
    await tester.enterText(
        find.byKey(const Key('field-new-password')), 'NewPass#2026');
    await tester.enterText(
        find.byKey(const Key('field-confirm-password')), 'NewPass#2026');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
    expect(find.text('HOME-ROUTE'), findsNothing);
    expect(session.mustChangePassword, isTrue);
  });
}