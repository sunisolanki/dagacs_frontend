import 'package:dagacs_frontend/core/context/hod_academic_context.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/core/theme/dagacs_theme.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/screens/hod/hod_structure_screen.dart';
import 'package:dagacs_frontend/widgets/app_module_scaffold.dart';
import 'package:dagacs_frontend/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 5.8 - accessibility.
///
/// The shared shell is the one component every role passes through, so it is
/// the right place to hold the accessibility floor. These tests pin the two
/// properties that a phone actually makes painful:
///
///   1. Tap targets big enough to hit with a thumb.
///   2. Layout that survives the OS "large font" setting rather than clipping
///      the very text it was enlarged for.
///
/// The second is the one worth having in a regression suite: a phone user with
/// a 30% larger system font is not an edge case, and Flutter's fixed test font
/// plus a text scale multiplier reproduces it deterministically.
const _phone = Size(320, 640);

/// 1.3 is Android's "Large" font setting; 2.0 is the accessibility range where
/// layouts are expected to reflow or scroll, never to clip.
const _largeFont = 1.3;
const _accessibilityFont = 2.0;

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();

  @override
  Future<void> persistSession(AuthResponse auth) async {}

  @override
  Future<void> logout() async {}
}

SessionController _session([String role = 'HOD']) {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession(role, email: 'a@b.test', fullName: 'Tester');
  return session;
}

/// The Android/iOS guidance for a comfortable touch target.
const _minTapTarget = 44.0;

void main() {
  group('touch targets', () {
    testWidgets('the navigation hamburger meets the minimum tap target',
        (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final session = _session('HOD');
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

      final size = tester.getSize(find.byTooltip('Open navigation'));
      expect(size.width, greaterThanOrEqualTo(_minTapTarget),
          reason: 'a 44 dp thumb target is the platform minimum');
      expect(size.height, greaterThanOrEqualTo(_minTapTarget));
    });

    testWidgets('every drawer destination meets the minimum tap target',
        (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final session = _session('HOD');
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
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();

      final tiles = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(ListTile),
      );
      expect(tiles, findsWidgets);

      for (final destination in appDestinationsFor('HOD')) {
        final tile = find.ancestor(
          of: find.descendant(
              of: find.byType(Drawer), matching: find.text(destination.label)),
          matching: find.byType(ListTile),
        );
        if (tile.evaluate().isEmpty) continue; // off-screen until scrolled
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(_minTapTarget),
            reason: '${destination.label} is too short to tap reliably');
      }
    });
  });

  group('large system font', () {
    for (final scale in [_largeFont, _accessibilityFont]) {
      testWidgets('the drawer survives a ${scale}x font at 320 dp', (tester) async {
        tester.view.physicalSize = _phone;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final session = _session('HOD');
        addTearDown(session.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildDagacsTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => AppShell(
                session: session,
                body: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open navigation'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'the drawer must not clip its own labels at ${scale}x font');
      });

      testWidgets('a HOD screen survives a ${scale}x font at 320 dp',
          (tester) async {
        tester.view.physicalSize = _phone;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final session = _session('HOD');
        addTearDown(session.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildDagacsTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: HodStructureScreen(
              session: session,
              academicContext: HodAcademicContext()
                ..select(HodContextLevel.academicSession, 1, name: '2026-27')
                ..select(HodContextLevel.program, 10, name: 'B.Tech CSE')
                ..select(HodContextLevel.semester, 100, name: 'Semester 3')
                ..select(HodContextLevel.section, 200, name: 'Section A'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'the HOD context shell must reflow at ${scale}x font, not '
                'clip - enlarging the text and then hiding it defeats the point');
      });
    }
  });

  group('semantics', () {
    testWidgets('the drawer announces itself as a navigation drawer',
        (tester) async {
      final handle = tester.ensureSemantics();

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final session = _session('STUDENT');
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

      // The drawer is only in the widget tree once it has been opened, which
      // is also the moment its accessible name matters to a screen reader.
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Navigation menu'),
        findsOneWidget,
        reason: 'a screen reader user must be able to identify the drawer',
      );

      handle.dispose();
    });

    testWidgets('a module screen drawer is labelled the same way',
        (tester) async {
      // AppModuleScaffold is a separate Drawer from the one in AppShell, so it
      // needs its own coverage or the fix could sit in only one of them.
      final handle = tester.ensureSemantics();

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final session = _session('TEACHER');
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDagacsTheme(),
          home: AppModuleScaffold(
            session: session,
            title: 'My Classes',
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Navigation menu'), findsOneWidget);

      handle.dispose();
    });
  });
}
