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

SessionController _session(String role) {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession(role);
  return session;
}

Widget _home(String role) {
  return MaterialApp(
    home: HomeScreen(
      session: _session(role),
      masterDataRepository: _FakeMasterDataRepository(),
    ),
  );
}

const _sizes = <Size>[
  Size(320, 720),
  Size(390, 844),
  Size(480, 800),
  Size(768, 1024),
  Size(1024, 768),
  Size(1280, 800),
  Size(1440, 900),
];

Future<void> _atSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pump();
}

void main() {
  group('role-aware welcome subtitle', () {
    const expectations = <String, String>{
      'ADMIN': 'Configure institutional master data and manage students',
      'TEACHER': 'Create sessions, mark attendance, and run reports',
      'HOD': 'Department analytics, coverage, reports, and teaching your assigned classes',
      'STUDENT': 'Track attendance and review your academic profile',
    };

    for (final entry in expectations.entries) {
      testWidgets('${entry.key} home shows the role-specific welcome subtitle',
          (tester) async {
        await tester.pumpWidget(_home(entry.key));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
      });
    }
  });

  group('role-aware module section heading', () {
    const expectations = <String, String>{
      'ADMIN': 'Command Center',
      'TEACHER': 'Attendance & Reporting',
      'HOD': 'Department Hub',
      'STUDENT': 'Academic Hub',
    };

    for (final entry in expectations.entries) {
      testWidgets('${entry.key} home shows a distinct section heading',
          (tester) async {
        await tester.pumpWidget(_home(entry.key));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
      });
    }
  });

  group('premium home responsiveness', () {
    const roles = <String>['ADMIN', 'TEACHER', 'HOD', 'STUDENT'];
    const pins = <String, String>{
      'ADMIN': 'Admin student master - create, edit, activate/deactivate',
      'TEACHER': 'Create sessions and mark student attendance',
      'HOD': 'Department analytics: attendance, low attendance, rollups',
      'STUDENT': 'View your academic profile details',
    };

    for (final role in roles) {
      for (final size in _sizes) {
        testWidgets(
            '$role home renders without overflow at ${size.width.toInt()}px',
            (tester) async {
          await _atSize(tester, size);
          await tester.pumpWidget(_home(role));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Welcome, $role'), findsOneWidget);
          expect(find.text(pins[role]!), findsOneWidget);
        });
      }
    }
  });
}