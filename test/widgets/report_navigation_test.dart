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

Future<void> _pumpHome(WidgetTester tester, String role) async {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession(role);
  await tester.pumpWidget(MaterialApp(
    home: HomeScreen(
      session: session,
      masterDataRepository: MasterDataRepository(ApiClient()),
    ),
  ));
}

void main() {
  testWidgets('HOD sees the Reports entry and it routes to /hod/reports',
      (tester) async {
    await _pumpHome(tester, 'HOD');
    expect(find.byKey(const Key('hod-reports-tile')), findsOneWidget);
    expect(find.byKey(const Key('teacher-reports-tile')), findsNothing);
  });

  testWidgets('TEACHER sees the Reports entry and it routes to /teacher/reports',
      (tester) async {
    await _pumpHome(tester, 'TEACHER');
    expect(find.byKey(const Key('teacher-reports-tile')), findsOneWidget);
    expect(find.byKey(const Key('hod-reports-tile')), findsNothing);
  });

  testWidgets('STUDENT cannot see any report entry', (tester) async {
    await _pumpHome(tester, 'STUDENT');
    expect(find.byKey(const Key('hod-reports-tile')), findsNothing);
    expect(find.byKey(const Key('teacher-reports-tile')), findsNothing);
  });

  testWidgets('ADMIN cannot see any report entry', (tester) async {
    await _pumpHome(tester, 'ADMIN');
    expect(find.byKey(const Key('hod-reports-tile')), findsNothing);
    expect(find.byKey(const Key('teacher-reports-tile')), findsNothing);
  });
}