import 'dart:async';

import 'package:dagacs_frontend/core/context/hod_academic_context.dart';
import 'package:dagacs_frontend/models/hod_hierarchy.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/hod_hierarchy_repository.dart';
import 'package:dagacs_frontend/services/hod_hierarchy_loader.dart';
import 'package:dagacs_frontend/widgets/dagacs_widgets.dart';
import 'package:dagacs_frontend/widgets/hod/hod_common.dart';
import 'package:dagacs_frontend/widgets/hod/hod_context_badges.dart';
import 'package:dagacs_frontend/widgets/hod/hod_context_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hierarchy fixture: two programs in one department and one session, matching
/// the shape the real API returns.
HodHierarchyRoot _root() => const HodHierarchyRoot(
      departmentId: 1,
      departmentName: 'CSE',
      departmentCode: 'CS',
      programs: [
        HodHierarchyOption(id: 10, name: 'B.Tech CSE', code: 'BTCSE'),
        HodHierarchyOption(id: 11, name: 'M.Tech CSE', code: 'MTCSE'),
      ],
      academicSessions: [
        HodHierarchyOption(
            id: 1, name: '2026-27', code: 'S1', programId: 10, programName: 'B.Tech CSE'),
      ],
    );

class _FakeHierarchyRepository extends HodHierarchyRepository {
  _FakeHierarchyRepository({this.root, this.error});

  final HodHierarchyRoot? root;
  final ApiException? error;
  Completer<HodHierarchyRoot>? pending;

  int rootCalls = 0;
  int semesterCalls = 0;
  int sectionCalls = 0;
  List<int?> requestedSemesterIds = [];
  List<int?> requestedSectionSemesterIds = [];

  @override
  Future<HodHierarchyRoot> getRoot() {
    rootCalls++;
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return Future.value(root ?? _root());
  }

  @override
  Future<List<HodHierarchyOption>> getSemesters({required int academicSessionId}) {
    semesterCalls++;
    if (error != null) throw error!;
    return Future.value(const [
      HodHierarchyOption(id: 100, name: 'Semester 3', code: 'S3'),
      HodHierarchyOption(id: 101, name: 'Semester 5', code: 'S5'),
    ]);
  }

  @override
  Future<List<HodHierarchyOption>> getSections({
    required int academicSessionId,
    int? programId,
    int? semesterId,
  }) {
    sectionCalls++;
    requestedSectionSemesterIds.add(semesterId);
    if (error != null) throw error!;
    return Future.value(const [
      HodHierarchyOption(
          id: 200, name: 'A', code: 'SEC-A', batchId: 10, batchName: 'Batch 1'),
      HodHierarchyOption(
          id: 201, name: 'B', code: 'SEC-B', batchId: 10, batchName: 'Batch 1'),
    ]);
  }
}

/// Coverage for the shared academic-context UI shell.
void main() {
  Widget _wrap(HodAcademicContext context, Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  group('HodContextBar', () {
    testWidgets('renders all five hierarchy levels in cascade order',
        (tester) async {
      final context = HodAcademicContext();
      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context)),
      ));
      await tester.pumpAndSettle();

      for (final label in const [
        'Academic Session',
        'Program',
        'Semester',
        'Section',
        'Subject',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('announces that filtering is unavailable when no loader is '
        'attached, and never shows fake options', (tester) async {
      final context = HodAcademicContext();
      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-context-pending-notice')), findsOneWidget);
      expect(find.textContaining('Academic context filtering is not available'),
          findsOneWidget);

      // No fabricated academic value is rendered.
      expect(find.textContaining('2026-27'), findsNothing);
      expect(find.textContaining('B.Tech'), findsNothing);
    });

    testWidgets('reports a loading hierarchy distinctly from an empty one',
        (tester) async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader = HodHierarchyLoader(repository: repository, context: context);
      repository.pending = Completer<HodHierarchyRoot>();

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context, loader: loader)),
      ));
      await tester.pump();
      loader.ensureRoot();
      await tester.pump();

      expect(find.byKey(const Key('hod-context-loading')), findsOneWidget);
      expect(find.text(hodHierarchyLoadingMessage), findsOneWidget);

      repository.pending!.complete(_root());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-context-loading')), findsNothing);
    });

    testWidgets('reports an empty hierarchy distinctly from a failure',
        (tester) async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository(
          root: const HodHierarchyRoot(departmentId: 1));
      final loader = HodHierarchyLoader(repository: repository, context: context);

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context, loader: loader)),
      ));
      loader.ensureRoot();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-context-empty')), findsOneWidget);
      expect(find.text(hodHierarchyEmptyMessage), findsOneWidget);
      expect(find.byKey(const Key('hod-context-error')), findsNothing);
    });

    testWidgets('surfaces a server failure instead of an empty selection',
        (tester) async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository(
          error: const ApiException.serverError());
      final loader = HodHierarchyLoader(repository: repository, context: context);

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context, loader: loader)),
      ));
      loader.ensureRoot();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-context-error')), findsOneWidget);
      expect(find.text(hodHierarchyErrorMessage), findsOneWidget);
      // A failure must not masquerade as "no academic data".
      expect(find.byKey(const Key('hod-context-empty')), findsNothing);
    });

    testWidgets('distinguishes unauthorized from a generic error',
        (tester) async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository(
          error: const ApiException(403, 'Forbidden'));
      final loader = HodHierarchyLoader(repository: repository, context: context);

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context, loader: loader)),
      ));
      loader.ensureRoot();
      await tester.pumpAndSettle();

      expect(loader.rootStatus, HodHierarchyStatus.unauthorized);
      expect(find.byKey(const Key('hod-context-unauthorized')), findsOneWidget);
      expect(find.text(hodHierarchyUnauthorizedMessage), findsOneWidget);
    });

    testWidgets('a real hierarchy enables the cascade roots and leaves deeper '
        'levels disabled until they hold data', (tester) async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader = HodHierarchyLoader(repository: repository, context: context);

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context, loader: loader)),
      ));
      loader.ensureRoot();
      await tester.pumpAndSettle();

      expect(loader.rootStatus, HodHierarchyStatus.ready);
      expect(context.hierarchyAvailable, isTrue);

      // The two cascade roots now hold real values and are usable.
      for (final level in const [
        HodContextLevel.academicSession,
        HodContextLevel.program,
      ]) {
        expect(
          tester
              .widget<AppFormDropdown<int>>(find.byKey(
                  Key('hod-context-dropdown-${level.name}')))
              .enabled,
          isTrue,
          reason: level.name,
        );
        expect(context.optionsFor(level), isNotEmpty, reason: level.name);
      }

      // Deeper levels have not been reached yet and stay disabled rather than
      // presenting an empty-but-usable control.
      for (final level in const [
        HodContextLevel.semester,
        HodContextLevel.section,
        HodContextLevel.subject,
      ]) {
        expect(
          tester
              .widget<AppFormDropdown<int>>(find.byKey(
                  Key('hod-context-dropdown-${level.name}')))
              .enabled,
          isFalse,
          reason: level.name,
        );
      }
    });

    testWidgets('selects a real session and loads only its semesters',
        (tester) async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader = HodHierarchyLoader(repository: repository, context: context);

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context, loader: loader)),
      ));
      loader.ensureRoot();
      await tester.pumpAndSettle();

      await tester.tap(
          find.byKey(const Key('hod-context-dropdown-academicSession')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-27 (S1)').last);
      await tester.pumpAndSettle();

      expect(context.academicSessionId, 1);
      expect(context.academicSessionName, '2026-27');
      // The dependent levels were fetched and published.
      expect(repository.semesterCalls, 1,
          reason: 'semesters are fetched once for the new session');
      expect(repository.sectionCalls, 1,
          reason: 'sections are fetched once for the new session');
      expect(repository.requestedSectionSemesterIds.single, isNull,
          reason: 'no semester is selected yet, so no semester filter is sent');
      expect(context.optionsFor(HodContextLevel.semester), isNotEmpty);
      expect(context.optionsFor(HodContextLevel.section), isNotEmpty);
      expect(
        tester
            .widget<AppFormDropdown<int>>(
                find.byKey(const Key('hod-context-dropdown-semester')))
            .enabled,
        isTrue,
      );
    });

    testWidgets('a program that does not belong to the selected session is '
        'never offered', (tester) async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader = HodHierarchyLoader(repository: repository, context: context);

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context, loader: loader)),
      ));
      loader.ensureRoot();
      await tester.pumpAndSettle();

      // Before a session is chosen, every department program is available.
      expect(context.optionsFor(HodContextLevel.program), hasLength(2));

      await tester.tap(
          find.byKey(const Key('hod-context-dropdown-academicSession')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-27 (S1)').last);
      await tester.pumpAndSettle();

      // The chosen session belongs to B.Tech CSE only, so M.Tech CSE cannot be
      // selected and the two programs can never be mixed.
      final programDropdown = tester.widget<AppFormDropdown<int>>(
          find.byKey(const Key('hod-context-dropdown-program')));
      expect(programDropdown.enabled, isTrue);
      expect(programDropdown.items, hasLength(1));
      final offered = programDropdown.items
          .map((item) => ((item.child as Text).data ?? ''))
          .toList();
      expect(offered.single, contains('B.Tech CSE'));
      expect(offered.any((label) => label.contains('M.Tech CSE')), isFalse,
          reason: 'an M.Tech program must not be offered for a B.Tech session');
    });

    testWidgets('selecting a semester refetches sections scoped to it',
        (tester) async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader = HodHierarchyLoader(repository: repository, context: context);

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context, loader: loader)),
      ));
      loader.ensureRoot();
      await tester.pumpAndSettle();

      await tester.tap(
          find.byKey(const Key('hod-context-dropdown-academicSession')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-27 (S1)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-context-dropdown-semester')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semester 3 (S3)').last);
      await tester.pumpAndSettle();

      expect(context.semesterId, 100);
      expect(repository.requestedSectionSemesterIds.last, 100,
          reason: 'the new semester is sent as a server-side section filter');
    });

    testWidgets('each level is disabled while the hierarchy is unavailable',
        (tester) async {
      final context = HodAcademicContext();
      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context)),
      ));
      await tester.pumpAndSettle();

      for (final level in HodAcademicContext.levels) {
        final dropdown = tester.widget<AppFormDropdown<int>>(
          find.byKey(Key('hod-context-dropdown-${level.name}')),
        );
        expect(dropdown.enabled, isFalse, reason: level.name);
      }

      // A disabled control opens nothing and offers no value.
      await tester.tap(find.byKey(const Key('hod-context-dropdown-semester')));
      await tester.pumpAndSettle();
      expect(find.text('Semester 3'), findsNothing);
    });

    testWidgets('verified options make the level interactive', (tester) async {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context.setOptions(HodContextLevel.semester, const [
        HodContextOption(id: 3, label: 'Semester 3'),
        HodContextOption(id: 4, label: 'Semester 4'),
      ]);

      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context)),
      ));
      await tester.pumpAndSettle();

      final dropdown = tester.widget<AppFormDropdown<int>>(
        find.byKey(const Key('hod-context-dropdown-semester')),
      );
      expect(dropdown.enabled, isTrue);
      expect(dropdown.items, hasLength(2));

      // Opening it reveals exactly the verified options.
      await tester.tap(find.byKey(const Key('hod-context-dropdown-semester')));
      await tester.pumpAndSettle();
      expect(find.text('Semester 3').last, findsOneWidget);
      expect(find.text('Semester 4').last, findsOneWidget);
    });

    testWidgets('a level with no supplied options offers nothing to pick',
        (tester) async {
      final context = HodAcademicContext()..markHierarchyAvailable();
      await tester.pumpWidget(_wrap(
        context,
        SingleChildScrollView(child: HodContextBar(context: context)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-context-dropdown-subject')));
      await tester.pumpAndSettle();

      expect(find.text('DSA'), findsNothing);
      expect(find.text('Semester 3'), findsNothing);
    });
  });

  group('HodContextBadges', () {
    testWidgets('states plainly when no context is selected', (tester) async {
      final context = HodAcademicContext();
      await tester.pumpWidget(
          _wrap(context, HodContextBadges(context: context)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-context-empty')), findsOneWidget);
      expect(find.text('No academic context selected'), findsOneWidget);
    });

    testWidgets('renders the selected trail parent to child', (tester) async {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
        ..select(HodContextLevel.semester, 3, name: 'Semester 3')
        ..select(HodContextLevel.section, 4, name: 'Section A');

      await tester.pumpWidget(
          _wrap(context, HodContextBadges(context: context)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-context-badges')), findsOneWidget);
      expect(find.text('2026-27'), findsOneWidget);
      expect(find.text('B.Tech CSE'), findsOneWidget);
      expect(find.text('Semester 3'), findsOneWidget);
      expect(find.text('Section A'), findsOneWidget);
      expect(find.byKey(const Key('hod-context-empty')), findsNothing);
    });
  });

  group('HodBreadcrumb', () {
    testWidgets('collapses entirely when nothing is selected',
        (tester) async {
      final context = HodAcademicContext();
      await tester.pumpWidget(
          _wrap(context, HodBreadcrumb(context: context)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-breadcrumb')), findsNothing);
    });

    testWidgets('mirrors the selected trail', (tester) async {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
        ..select(HodContextLevel.semester, 3, name: 'Semester 3');

      await tester.pumpWidget(
          _wrap(context, HodBreadcrumb(context: context)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-breadcrumb')), findsOneWidget);
      expect(find.text('B.Tech CSE'), findsOneWidget);
      expect(find.text('Semester 3'), findsOneWidget);
    });
  });

  group('formatHodPercentage', () {
    test('always uses two decimal places', () {
      expect(formatHodPercentage(80), '80.00%');
      expect(formatHodPercentage(76.923), '76.92%');
      expect(formatHodPercentage(100), '100.00%');
      expect(formatHodPercentage(0), '0.00%');
    });

    test('a null value renders no-data, never 0%', () {
      expect(formatHodPercentage(null), 'No data');
    });
  });
}
