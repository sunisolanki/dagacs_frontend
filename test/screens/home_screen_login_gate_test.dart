import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());
}

SessionController _session(String role, bool mustChangePassword) {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession(role, mustChangePassword: mustChangePassword);
  return session;
}

/// Builds the app as it would after a persisted session restore: the routed
/// change-password screen is registered so the deep-link is observable, and a
/// stale flag can be passed in for any role.
Widget _home(String role, bool mustChangePassword) {
  return MaterialApp(
    onGenerateRoute: (settings) {
      switch (settings.name) {
        case '/student/change-password':
          return MaterialPageRoute(
              builder: (_) =>
                  const Scaffold(body: Text('CHANGE-PASSWORD-ROUTE')));
        default:
          return MaterialPageRoute(builder: (_) => const SizedBox());
      }
    },
    home: HomeScreen(
      session: _session(role, mustChangePassword),
      masterDataRepository: _FakeMasterDataRepository(),
    ),
  );
}

void main() {
  testWidgets('student restore with mustChangePassword enters change flow',
      (tester) async {
    await tester.pumpWidget(_home('STUDENT', true));
    await tester.pumpAndSettle();
    expect(find.text('CHANGE-PASSWORD-ROUTE'), findsOneWidget);
  });

  for (final role in ['HOD', 'TEACHER', 'ADMIN']) {
    testWidgets('$role restore with stale flag stays on home, not the '
        'change-flow trap', (tester) async {
      await tester.pumpWidget(_home(role, true));
      await tester.pumpAndSettle();
      expect(find.text('Welcome, $role'), findsOneWidget,
          reason: 'M10A: $role with a stale flag must reach its normal home');
      expect(find.text('CHANGE-PASSWORD-ROUTE'), findsNothing,
          reason: 'M10A: deep-link/session restore must not trap a non-student');
    });
  }

  testWidgets('student restore without flag stays on home', (tester) async {
    await tester.pumpWidget(_home('STUDENT', false));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, STUDENT'), findsOneWidget);
    expect(find.text('CHANGE-PASSWORD-ROUTE'), findsNothing);
  });
}