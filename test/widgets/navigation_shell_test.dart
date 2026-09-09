import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/home_screen.dart';
import 'package:dagacs_frontend/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records pushed route names so navigation is asserted on the actual route,
/// not merely on the presence of a widget.
class _RouteObserver extends NavigatorObserver {
  final List<String> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
  }
}

SessionController _sessionFor(String role) {
  final session = SessionController(AuthRepository());
  session.establishSession(role,
      fullName: 'Test User', email: 'test@example.com');
  return session;
}

/// Every route resolves to an [AppShell] carrying the route name, so the shell
/// can be asserted on any route (including module sub-routes).
Widget _shellApp(
  String role, {
  String initialRoute = AppRoutes.home,
  _RouteObserver? observer,
}) {
  final session = _sessionFor(role);
  return MaterialApp(
    navigatorObservers: observer == null ? const [] : [observer],
    initialRoute: initialRoute,
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => AppShell(
        session: session,
        body: Center(child: Text('body:${settings.name}')),
      ),
    ),
  );
}

Future<void> _sizeTo(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pump();
}

/// Reads the shell's [ListTile] carrying [label].
ListTile _navTile(WidgetTester tester, String label) => tester.widget<ListTile>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(ListTile),
      ),
    );

const _desktop = Size(1280, 900);
const _tablet = Size(800, 600);
const _mobile = Size(375, 800);

void main() {
  group('shell rendering', () {
    testWidgets('renders brand, body and side navigation at desktop width',
        (tester) async {
      await _sizeTo(tester, _desktop);
      await tester.pumpWidget(_shellApp('TEACHER'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('DAGACS'), findsOneWidget);
      expect(find.text('body:/home'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('renders without overflow at a 320px viewport', (tester) async {
      await _sizeTo(tester, const Size(320, 600));
      await tester.pumpWidget(_shellApp('TEACHER'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('DAGACS'), findsOneWidget);
    });

    testWidgets('narrow viewport keeps the drawer closed and hides side nav',
        (tester) async {
      await _sizeTo(tester, _mobile);
      await tester.pumpWidget(_shellApp('TEACHER'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open navigation'), findsOneWidget);
      expect(find.text('Overview'), findsNothing);
    });
  });

  group('role-aware destinations', () {
    testWidgets('STUDENT sees only student destinations', (tester) async {
      await _sizeTo(tester, _desktop);
      await tester.pumpWidget(_shellApp('STUDENT'));
      await tester.pumpAndSettle();

      expect(find.text('My Attendance'), findsOneWidget);
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Master Data'), findsNothing);
      expect(find.text('Students'), findsNothing);
      expect(find.text('Analytics'), findsNothing);
    });

    testWidgets('HOD sees only HOD destinations', (tester) async {
      await _sizeTo(tester, _desktop);
      await tester.pumpWidget(_shellApp('HOD'));
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Master Data'), findsNothing);
      expect(find.text('My Profile'), findsNothing);
    });
  });

  group('active route highlighting', () {
    testWidgets('highlights the destination matching the current route',
        (tester) async {
      await _sizeTo(tester, _desktop);
      await tester.pumpWidget(
          _shellApp('TEACHER', initialRoute: AppRoutes.teacherAttendance));
      await tester.pumpAndSettle();

      expect(_navTile(tester, 'Attendance').selected, isTrue);
      expect(_navTile(tester, 'Overview').selected, isFalse);
      expect(_navTile(tester, 'Reports').selected, isFalse);
    });

    testWidgets('keeps the parent destination highlighted on a sub-route',
        (tester) async {
      await _sizeTo(tester, _desktop);
      await tester.pumpWidget(_shellApp('ADMIN',
          initialRoute: AppRoutes.masterDataDepartments));
      await tester.pumpAndSettle();

      expect(_navTile(tester, 'Master Data').selected, isTrue);
      expect(_navTile(tester, 'Overview').selected, isFalse);
    });

    testWidgets('highlights Overview on the home route', (tester) async {
      await _sizeTo(tester, _desktop);
      await tester.pumpWidget(_shellApp('TEACHER'));
      await tester.pumpAndSettle();

      expect(_navTile(tester, 'Overview').selected, isTrue);
      expect(_navTile(tester, 'Attendance').selected, isFalse);
    });
  });

  group('navigation behaviour', () {
    testWidgets('tapping a destination pushes that route', (tester) async {
      await _sizeTo(tester, _desktop);
      final observer = _RouteObserver();
      await tester.pumpWidget(_shellApp('TEACHER', observer: observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(observer.pushed.last, AppRoutes.teacherAttendance);
      expect(find.text('body:/teacher/attendance'), findsOneWidget);
    });

    testWidgets('tapping the active destination does not push a duplicate',
        (tester) async {
      await _sizeTo(tester, _desktop);
      final observer = _RouteObserver();
      await tester.pumpWidget(_shellApp('TEACHER',
          initialRoute: AppRoutes.teacherAttendance, observer: observer));
      await tester.pumpAndSettle();
      final pushCount = observer.pushed.length;

      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(observer.pushed.length, pushCount);
    });

    testWidgets('tapping the parent destination from a sub-route is idempotent',
        (tester) async {
      await _sizeTo(tester, _desktop);
      final observer = _RouteObserver();
      await tester.pumpWidget(_shellApp('ADMIN',
          initialRoute: AppRoutes.masterDataDepartments, observer: observer));
      await tester.pumpAndSettle();
      final pushCount = observer.pushed.length;

      await tester.tap(find.text('Master Data'));
      await tester.pumpAndSettle();

      expect(observer.pushed.length, pushCount);
    });

    testWidgets('navigating home from another route still pushes',
        (tester) async {
      await _sizeTo(tester, _desktop);
      final observer = _RouteObserver();
      await tester.pumpWidget(_shellApp('TEACHER',
          initialRoute: AppRoutes.teacherAttendance, observer: observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      expect(observer.pushed.last, AppRoutes.home);
    });
  });

  group('mobile drawer', () {
    testWidgets('opens, navigates to the tapped route and closes',
        (tester) async {
      await _sizeTo(tester, _mobile);
      final observer = _RouteObserver();
      await tester.pumpWidget(_shellApp('TEACHER', observer: observer));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);

      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(observer.pushed.last, AppRoutes.teacherAttendance);
      expect(find.text('body:/teacher/attendance'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('closes without pushing when the active route is tapped',
        (tester) async {
      await _sizeTo(tester, _mobile);
      final observer = _RouteObserver();
      await tester.pumpWidget(_shellApp('TEACHER',
          initialRoute: AppRoutes.teacherAttendance, observer: observer));
      await tester.pumpAndSettle();
      final pushCount = observer.pushed.length;

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(observer.pushed.length, pushCount);
      expect(find.byType(Drawer), findsNothing);
    });
  });

  group('no duplicate navigation labels', () {
    Widget homeApp(String role) => MaterialApp(
          home: HomeScreen(
            session: _sessionFor(role),
            masterDataRepository: MasterDataRepository(ApiClient()),
          ),
        );

    testWidgets('side navigation label is not repeated by a home tile',
        (tester) async {
      await _sizeTo(tester, _desktop);
      await tester.pumpWidget(homeApp('TEACHER'));
      await tester.pumpAndSettle();

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets('home tile keeps its label when the side nav is hidden',
        (tester) async {
      await _sizeTo(tester, _tablet);
      await tester.pumpWidget(homeApp('TEACHER'));
      await tester.pumpAndSettle();

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets('STUDENT labels appear exactly once at both breakpoints',
        (tester) async {
      await _sizeTo(tester, _desktop);
      await tester.pumpWidget(homeApp('STUDENT'));
      await tester.pumpAndSettle();
      expect(find.text('My Attendance'), findsOneWidget);
      expect(find.text('My Profile'), findsOneWidget);

      await _sizeTo(tester, _tablet);
      await tester.pumpWidget(homeApp('STUDENT'));
      await tester.pumpAndSettle();
      expect(find.text('My Attendance'), findsOneWidget);
      expect(find.text('My Profile'), findsOneWidget);
    });
  });
}