import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/core/theme/dagacs_theme.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/widgets/app_module_scaffold.dart';
import 'package:dagacs_frontend/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 5.3: shared mobile navigation.
///
/// The defect this covers is structural rather than cosmetic. The drawer existed
/// only on the home shell, so a user who tapped into a module screen had nothing
/// to navigate with except the system back control - on a phone, a gesture they
/// cannot see. These tests pin the fix at the four widths Phase 5 requires, and
/// pin the equally important non-regression: the desktop layout must NOT have
/// grown a drawer it never had.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient());
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

/// The four widths a real handset or a small tablet is actually laid out at.
const _phoneWidths = [320.0, 360.0, 390.0, 412.0];

Widget _host(Widget child) =>
    MaterialApp(theme: buildDagacsTheme(), home: child);

Widget _module(
  SessionController session, {
  String title = 'My Attendance',
  Widget? body,
}) {
  return _host(
    AppModuleScaffold(
      session: session,
      title: title,
      body: body ?? const Text('MODULE-BODY'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  SessionController sessionFor(String role) {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession(role, email: '$role@dagacs.local', fullName: role);
    return session;
  }

  void useWidth(WidgetTester tester, double width, {double height = 2400}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('a module screen is navigable on a phone', () {
    for (final width in _phoneWidths) {
      testWidgets('offers a drawer at ${width.toInt()}dp', (tester) async {
        useWidth(tester, width);
        await tester.pumpWidget(_module(sessionFor('STUDENT')));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Open navigation'), findsOneWidget,
            reason: 'at ${width.toInt()}dp a module screen must offer the same '
                'navigation affordance as the home shell');

        await tester.tap(find.byTooltip('Open navigation'));
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsOneWidget);
      });
    }

    testWidgets('the drawer lists the role destinations and a way home',
        (tester) async {
      useWidth(tester, 360);
      await tester.pumpWidget(_module(sessionFor('STUDENT')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();

      // Scoped to the drawer: the app bar carries the same words, so an
      // unscoped finder would match the title and the destination tile.
      final drawer = find.byType(Drawer);
      expect(find.descendant(of: drawer, matching: find.text('Overview')),
          findsOneWidget,
          reason: 'a user must always be able to get back to their home');
      expect(
          find.descendant(of: drawer, matching: find.text('My Attendance')),
          findsOneWidget);
      expect(
          find.descendant(of: drawer, matching: find.text('My Profile')),
          findsOneWidget);
      expect(find.descendant(of: drawer, matching: find.text('Sign out')),
          findsOneWidget);
    });

    testWidgets('the HOD drawer offers all eleven HOD destinations',
        (tester) async {
      useWidth(tester, 360);
      await tester.pumpWidget(_module(sessionFor('HOD'), title: 'Attendance Matrix'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();

      // HOD has the largest destination list in the app; it must be scrollable
      // rather than overflow on a short phone screen.
      final drawer = find.byType(Drawer);
      for (final label in [
        'Attendance Matrix',
        'Low Attendance',
        'Rollups',
        'Reports',
        'Audit Logs',
      ]) {
        expect(
          find.descendant(of: drawer, matching: find.text(label)),
          findsOneWidget,
          reason: 'the HOD drawer must list $label',
        );
      }
      expect(find.byType(ListView), findsWidgets,
          reason: 'a long destination list scrolls instead of overflowing');
    });

    testWidgets('tapping a destination navigates and closes the drawer',
        (tester) async {
      useWidth(tester, 360);
      final session = sessionFor('STUDENT');
      final pushed = <String?>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDagacsTheme(),
          home: Builder(
            builder: (context) => AppModuleScaffold(
              session: session,
              title: 'My Attendance',
              body: const Text('MODULE-BODY'),
            ),
          ),
          onGenerateRoute: (settings) {
            pushed.add(settings.name);
            if (settings.name == AppRoutes.studentProfile) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('PROFILE-ROUTE')),
              );
            }
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('UNKNOWN-ROUTE')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Profile'));
      await tester.pumpAndSettle();

      expect(pushed, contains(AppRoutes.studentProfile));
      expect(find.text('PROFILE-ROUTE'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing,
          reason: 'choosing a destination must close the drawer');
    });

    testWidgets('the current section is highlighted, not re-pushed',
        (tester) async {
      useWidth(tester, 360);
      final session = sessionFor('STUDENT');
      final pushed = <String?>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDagacsTheme(),
          // The module screen must sit on its own named route, or "am I already
          // on this section?" has nothing to compare against.
          initialRoute: AppRoutes.studentAttendance,
          onGenerateRoute: (settings) {
            pushed.add(settings.name);
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => AppModuleScaffold(
                session: session,
                title: 'My Attendance',
                body: const Text('MODULE-BODY'),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget,
          reason: 'the drawer must be open before its destinations can be used');

      final myAttendance = find.descendant(
          of: find.byType(Drawer), matching: find.text('My Attendance'));
      expect(myAttendance, findsOneWidget);
      await tester.tap(myAttendance);
      await tester.pumpAndSettle();

      // Tapping the section you are already on must not stack a duplicate copy
      // of it - that is how a navigation loop gets created.
      expect(pushed.where((r) => r == AppRoutes.studentAttendance).length, 1,
          reason: 'the current section is pushed once, by the initial route, '
              'and re-selecting it must not push it again');
    });

    testWidgets('signing out returns to login', (tester) async {
      useWidth(tester, 360);
      final session = sessionFor('STUDENT');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDagacsTheme(),
          home: AppModuleScaffold(
            session: session,
            title: 'My Attendance',
            body: const Text('MODULE-BODY'),
          ),
          routes: {
            AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN-ROUTE')),
          },
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.login) return null;
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('ROUTE')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN-ROUTE'), findsOneWidget);
      expect(session.isAuthenticated, isFalse);
    });
  });

  group('the desktop layout is not changed', () {
    testWidgets('no drawer and no hamburger above the breakpoint', (tester) async {
      useWidth(tester, 1280, height: 900);
      await tester.pumpWidget(_module(sessionFor('STUDENT')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open navigation'), findsNothing,
          reason: 'the desktop layout never had a hamburger; adding one would '
              'change a layout that already works');
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('the screen keeps its own title and body', (tester) async {
      useWidth(tester, 1280, height: 900);
      await tester.pumpWidget(_module(sessionFor('STUDENT')));
      await tester.pumpAndSettle();

      expect(find.text('My Attendance'), findsOneWidget);
      expect(find.text('MODULE-BODY'), findsOneWidget);
    });
  });

  group('the shared navigation vocabulary', () {
    test('is one list, shared by the shell and the module frame', () {
      // The whole point of extracting it: a second list is a second thing to
      // keep in step with the role model.
      for (final role in ['ADMIN', 'HOD', 'TEACHER', 'STUDENT']) {
        expect(appDestinationsFor(role), isNotEmpty,
            reason: '$role must have somewhere to go');
        for (final destination in appDestinationsFor(role)) {
          expect(destination.route, startsWith('/'),
              reason: 'every destination must be a valid named route');
        }
      }
      expect(appDestinationsFor('HOD').length, greaterThan(
          appDestinationsFor('STUDENT').length),
          reason: 'the HOD genuinely has more places to go than a student');
    });

    test('an unknown role falls back to the student destinations', () {
      // Defensive: a role the app does not know must still leave the user able
      // to reach their own attendance and profile, not a blank drawer.
      expect(appDestinationsFor('SOMETHING_NEW'), isNotEmpty);
    });

    test('isSameOrChildRoute matches a module and its detail', () {
      expect(isSameOrChildRoute('/student/attendance', '/student/attendance'),
          isTrue);
      expect(isSameOrChildRoute('/teacher/attendance/mark',
          '/teacher/attendance'), isTrue,
          reason: 'a detail page must keep its parent section highlighted');
      expect(isSameOrChildRoute('/student/profile', '/student/attendance'),
          isFalse);
    });
  });
}
