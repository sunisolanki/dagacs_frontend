import 'package:dagacs_frontend/core/context/hod_academic_context.dart';
import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/core/theme/dagacs_theme.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/screens/hod/hod_structure_screen.dart';
import 'package:dagacs_frontend/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 5.6: the HOD surface is the largest in the app - eleven destinations
/// behind one shared shell. Those screens already route through [HodScaffold],
/// so this file is primarily *verification* that the shared shell really is
/// phone-safe, plus a guard that every HOD destination stays declared.
const _phone = Size(320, 640);
const _desktop = Size(1400, 900);

SessionController _hodSession() {
  final session = SessionController(AuthRepository());
  session.establishSession('HOD',
      email: 'hod@dagacs.test', fullName: 'Head of Department');
  return session;
}

HodAcademicContext _fullContext() => HodAcademicContext()
  ..select(HodContextLevel.academicSession, 1, name: '2026-27')
  ..select(HodContextLevel.program, 10, name: 'B.Tech CSE')
  ..select(HodContextLevel.semester, 100, name: 'Semester 3')
  ..select(HodContextLevel.section, 200, name: 'Section A');

void main() {
  group('HOD shared shell on a phone', () {
    testWidgets('the drawer lists every HOD destination and scrolls',
        (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final session = _hodSession();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDagacsTheme(),
          home: Builder(
            builder: (context) => AppShell(
              session: session,
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open navigation'), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();

      final drawer = find.byType(Drawer);
      expect(drawer, findsOneWidget);

      // Every declared HOD destination must actually be reachable from the
      // drawer. This is the check that keeps the HOD menu honest as routes are
      // added, rather than trusting that "the shell has a drawer" implies the
      // drawer is complete.
      final destinations = appDestinationsFor('HOD');
      expect(destinations.length, 11,
          reason: 'the HOD menu is the largest in the app; a silent drop here '
              'would make a module unreachable on a phone');

      for (final destination in destinations) {
        await tester.scrollUntilVisible(
          find.descendant(of: drawer, matching: find.text(destination.label)),
          120,
          scrollable: find.descendant(of: drawer, matching: find.byType(Scrollable)),
        );
        expect(
          find.descendant(of: drawer, matching: find.text(destination.label)),
          findsOneWidget,
          reason: 'the drawer must offer ${destination.label}',
        );
      }

      expect(
        find.descendant(of: drawer, matching: find.text('Sign out')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull,
          reason: 'eleven destinations must not overflow a 320 dp drawer');
    });

    testWidgets('the wide shell is unchanged', (tester) async {
      tester.view.physicalSize = _desktop;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final session = _hodSession();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDagacsTheme(),
          home: Builder(
            builder: (context) => AppShell(
              session: session,
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open navigation'), findsNothing,
          reason: 'a desktop window keeps the rail and gains no hamburger');
      expect(find.byType(Drawer), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every HOD destination has a real route', (tester) async {
      // A destination pointing at a route the router cannot resolve would be
      // a dead end on a phone, where the rail is gone.
      final routes = <String>{
        AppRoutes.hodDashboard,
        AppRoutes.hodStructure,
        AppRoutes.hodSections,
        AppRoutes.hodSubjects,
        AppRoutes.hodStudents,
        AppRoutes.hodLowAttendance,
        AppRoutes.hodRollups,
        AppRoutes.hodAttendanceMatrix,
        AppRoutes.hodReports,
        AppRoutes.hodAuditLogs,
        AppRoutes.masterData,
        // The HOD menu also offers "My Classes". That is deliberate, not a
        // leak: SecurityConfig authorises /api/teacher/** for TEACHER *and* HOD.
        AppRoutes.teacherClasses,
      };
      final declared =
          appDestinationsFor('HOD').map((d) => d.route).toSet();
      expect(declared.difference(routes), isEmpty,
          reason: 'the drawer must not advertise a route the router lacks');
    });

    testWidgets('a real HOD screen renders without overflow at 320 dp',
        (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final session = _hodSession();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDagacsTheme(),
          home: HodStructureScreen(
            session: session,
            // A fully populated context is the honest case: every context bar
            // and breadcrumb level is rendered at once, which is exactly the
            // combination that squeezes on a narrow screen.
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Structure'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'the HOD context shell must fit a 320 dp phone');
    });
  });
}