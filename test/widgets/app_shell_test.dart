import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionController _sessionFor(String role) {
  final session = SessionController(AuthRepository());
  session.establishSession(role, fullName: 'Test User', email: 'test@example.com');
  return session;
}

Widget _app(String role) => MaterialApp(
      home: AppShell(
        session: _sessionFor(role),
        body: const Center(child: Text('Dashboard content')),
      ),
    );

void main() {
  testWidgets('admin shell shows only supported administrative destinations',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app('ADMIN'));

    expect(find.text('Master Data'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Attendance'), findsNothing);
    expect(find.text('My Profile'), findsNothing);
  });

  testWidgets('teacher shell uses the compact drawer at mobile width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app('TEACHER'));
    expect(find.text('Attendance'), findsNothing);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Master Data'), findsNothing);
  });
}
