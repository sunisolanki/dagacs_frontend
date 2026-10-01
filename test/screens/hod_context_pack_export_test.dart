import 'dart:async';
import 'dart:typed_data';

import 'package:dagacs_frontend/core/context/hod_academic_context.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/core/theme/dagacs_theme.dart';
import 'package:dagacs_frontend/models/hod_attendance_matrix.dart';
import 'package:dagacs_frontend/models/hod_attendance_overview.dart';
import 'package:dagacs_frontend/models/hod_low_attendance_report.dart';
import 'package:dagacs_frontend/models/report_export.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/hod_attendance_repository.dart';
import 'package:dagacs_frontend/repositories/hod_repository.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
import 'package:dagacs_frontend/screens/hod_reports_screen.dart';
import 'package:dagacs_frontend/widgets/dagacs_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dagacs_frontend/widgets/hod/hod_export_bar.dart';

/// One export attempt, recorded with the context it was made for.
class PackCall {
  PackCall(this.method, this.format, {this.academicSessionId, this.programId,
      this.semesterId, this.sectionId, this.startDate, this.endDate});

  final String method;
  final String format;
  final int? academicSessionId;
  final int? programId;
  final int? semesterId;
  final int? sectionId;
  final DateTime? startDate;
  final DateTime? endDate;
}

/// Records every export instead of issuing a request, and serves canned report
/// data so a panel can reach its loaded state.
class _RecordingRepository extends HodAttendanceRepository {
  final List<PackCall> calls = [];

  /// Blocks an export until completed, so the generating state is observable.
  Completer<void>? gate;

  /// When set, the next export fails with this error.
  Object? nextError;

  int overviewCalls = 0;

  Future<DownloadPayload> _record(PackCall call) async {
    calls.add(call);
    final waiting = gate;
    if (waiting != null) await waiting.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    return DownloadPayload(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: '${call.method}.${call.format}',
      contentType: 'application/octet-stream',
    );
  }

  @override
  Future<DownloadPayload> exportContextPack(
    String format, {
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _record(PackCall('context-pack', format,
          academicSessionId: academicSessionId,
          programId: programId,
          semesterId: semesterId,
          sectionId: sectionId,
          startDate: startDate,
          endDate: endDate));

  @override
  Future<DownloadPayload> exportOverview(
    String format, {
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _record(PackCall('overview', format,
          academicSessionId: academicSessionId,
          programId: programId,
          semesterId: semesterId,
          sectionId: sectionId,
          startDate: startDate,
          endDate: endDate));

  @override
  Future<DownloadPayload> exportMatrix(
    String format, {
    required int? academicSessionId,
    required int? programId,
    required int? semesterId,
    required int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _record(PackCall('matrix', format,
          academicSessionId: academicSessionId,
          programId: programId,
          semesterId: semesterId,
          sectionId: sectionId,
          startDate: startDate,
          endDate: endDate));

  @override
  Future<HodAttendanceOverview> getOverview({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    overviewCalls++;
    return _overview;
  }

  @override
  Future<HodAttendanceMatrix> getMatrix({
    required int? academicSessionId,
    required int? programId,
    required int? semesterId,
    required int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 0,
    int size = 50,
    String sortBy = 'enrollmentNumber',
    String direction = 'asc',
  }) async =>
      _matrix;

  @override
  Future<HodLowAttendanceReport> getLowAttendance({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      _low;
}

class _StubHodRepository extends HodRepository {
  _StubHodRepository();
}

class _StubReportRepository extends ReportRepository {
  _StubReportRepository();
}

/// A fully-resolved context whose levels also carry options, so the context bar
/// is genuinely usable and a level change can be driven through the real UI.
HodAcademicContext _fullContext() {
  final context = HodAcademicContext()..markHierarchyAvailable();
  context
    ..select(HodContextLevel.academicSession, 1, name: 'Academic Session 2026-27')
    ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
    ..select(HodContextLevel.semester, 3, name: 'Semester 3')
    ..select(HodContextLevel.section, 4, name: 'A')
    ..setOptions(HodContextLevel.academicSession, const [
      HodContextOption(id: 1, label: 'Academic Session 2026-27'),
    ])
    ..setOptions(HodContextLevel.program, const [
      HodContextOption(id: 2, label: 'B.Tech CSE', code: 'CSE'),
    ])
    ..setOptions(HodContextLevel.semester, const [
      HodContextOption(id: 3, label: 'Semester 3'),
    ])
    ..setOptions(HodContextLevel.section, const [
      HodContextOption(id: 4, label: 'A'),
      HodContextOption(id: 9, label: 'B'),
    ])
    ..setOptions(HodContextLevel.subject, const [
      HodContextOption(id: 101, label: 'CS301 Data Structures'),
    ]);
  return context;
}

/// The same context, already carrying an applied date range.
HodAcademicContext _contextWithRange() {
  final context = _fullContext()
    ..setStartDate(DateTime(2026, 1, 1))
    ..setEndDate(DateTime(2026, 1, 31));
  return context;
}

/// A context holding only the academic session: not enough for a cross-tab.
HodAcademicContext _sessionOnlyContext() {
  final context = HodAcademicContext()..markHierarchyAvailable();
  context
    ..select(HodContextLevel.academicSession, 1, name: 'Academic Session 2026-27')
    ..setOptions(HodContextLevel.academicSession, const [
      HodContextOption(id: 1, label: 'Academic Session 2026-27'),
    ]);
  return context;
}

SessionController _session() {
  final session = SessionController(AuthRepository());
  session.establishSession('HOD',
      fullName: 'HOD User', email: 'hod@dagacs.local');
  return session;
}

final _matrix = HodAttendanceMatrix.fromJson({
  'context': {'complete': true},
  'subjects': [
    {
      'subjectId': 101,
      'subjectCode': 'CS301',
      'subjectName': 'Data Structures',
      'facultyNames': ['Dr Rao'],
    },
  ],
  'students': [
    {
      'studentId': 91,
      'enrollmentNumber': 'CS2025001',
      'rollNumber': 'R1',
      'studentName': 'Rahul',
      'sectionName': 'A',
      'subjects': [
        {'subjectId': 101, 'present': 32, 'total': 40, 'percentage': 80.0},
      ],
      'totalPresent': 32,
      'totalClasses': 40,
      'overallPercentage': 80.0,
    },
  ],
  'page': 0,
  'size': 50,
  'totalElements': 1,
  'totalPages': 1,
  'singleSubject': false,
  'thresholdPercentage': 75.0,
});

final _overview = HodAttendanceOverview.fromJson({
  'context': {'complete': true},
  'totalStudents': 1,
  'overallPresentCount': 32,
  'overallTotalClasses': 40,
  'overallPercentage': 80.0,
  'classesConducted': 40,
  'thresholdPercentage': 75.0,
  'belowThresholdCount': 0,
  'noConductedClasses': 0,
  'distribution': <dynamic>[],
  'subjects': [
    {
      'subjectId': 101,
      'subjectCode': 'CS301',
      'subjectName': 'Data Structures',
      'facultyNames': ['Dr Rao'],
      'classesConducted': 40,
      'presentCount': 32,
      'totalClasses': 40,
      'percentage': 80.0,
    },
  ],
});

final _low = HodLowAttendanceReport.fromJson({
  'context': {'complete': true},
  'thresholdPercentage': 75.0,
  'totalStudents': 1,
  'belowThresholdCount': 0,
  'students': <dynamic>[],
});

Widget _host(Widget child) => MaterialApp(
      theme: buildDagacsTheme(),
      home: Scaffold(body: child),
    );

/// The shared context shell needs a larger surface than the default 800x600
/// test viewport; the production layout is unaffected.
void _largeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _hub(
  _RecordingRepository repository, {
  HodAcademicContext? academicContext,
}) =>
    _host(
      HodReportsScreen(
        hodRepository: _StubHodRepository(),
        reportRepository: _StubReportRepository(),
        attendanceRepository: repository,
        session: _session(),
        academicContext: academicContext ?? _fullContext(),
        downloadFile: (bytes, name, type) async => 'Downloaded $name',
      ),
    );

Future<void> _selectSection(WidgetTester tester, String reportType) async {
  await tester.tap(find.byKey(Key('report-type-$reportType')));
  await tester.pumpAndSettle();
}

/// The five sheets the backend builds, in workbook order.
const _expectedSheets = [
  'Executive Summary',
  'Attendance Matrix',
  'Low Attendance',
  'Subject Summary',
  'Student Summary',
];

void main() {
  group('Context Pack export', () {
    testWidgets('the button exists on the hub and names the pack',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-export-pack')), findsOneWidget);
      expect(find.text('Context Pack'), findsOneWidget);

      final tooltips =
          tester.widgetList<Tooltip>(find.byType(Tooltip)).map((t) => t.message);
      // The tooltip states exactly what is in the file, so a HOD knows what they
      // are about to download before spending the wait on it.
      for (final sheet in _expectedSheets) {
        expect(tooltips, anyElement(contains(sheet)),
            reason: 'the tooltip must list the $sheet sheet');
      }
    });

    testWidgets('tapping it requests the Context Pack endpoint',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(1));
      expect(repository.calls.single.method, 'context-pack');
      expect(repository.calls.single.format, 'xlsx');
    });

    testWidgets('the pack carries the context the report was loaded for',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pumpAndSettle();

      final call = repository.calls.single;
      expect(call.academicSessionId, 1);
      expect(call.programId, 2);
      expect(call.semesterId, 3);
      expect(call.sectionId, 4);
    });

    testWidgets('the pack carries the applied date range', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(
          _hub(repository, academicContext: _contextWithRange()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pumpAndSettle();

      final call = repository.calls.single;
      expect(call.startDate, DateTime(2026, 1, 1));
      expect(call.endDate, DateTime(2026, 1, 31));
    });

    testWidgets('a context the panel has not reloaded for is never packed',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      final context = _fullContext();
      await tester.pumpWidget(_hub(repository, academicContext: context));
      await tester.pumpAndSettle();

      // The model moves on but the panel has not refetched, so the screen still
      // shows section A. The workbook must therefore still describe section A.
      context.select(HodContextLevel.section, 9, name: 'B');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pumpAndSettle();

      expect(repository.calls.single.sectionId, 4,
          reason: 'the file must match the report actually on screen');
    });

    testWidgets('an incomplete context refuses the pack and issues no request',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(
          _hub(repository, academicContext: _sessionOnlyContext()));
      await tester.pumpAndSettle();

      await _selectSection(tester, 'context-overview');

      final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('hod-export-pack')));
      expect(button.onPressed, isNull,
          reason: 'a pack contains a cross-tab and needs all four levels');
      expect(repository.calls, isEmpty,
          reason: 'a mixed-context pack must never be requested');
    });

    testWidgets('a double tap issues exactly one request', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository()..gate = Completer<void>();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hod-export-pack')), warnIfMissed: false);
      await tester.pump();

      expect(repository.calls, hasLength(1),
          reason: 'a second click must not start a second generation');

      repository.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the academic context is locked while the pack generates',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository()..gate = Completer<void>();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppFormDropdown<int>>(
              find.byKey(const Key('hod-context-dropdown-section')),
            )
            .enabled,
        isTrue,
        reason: 'baseline: the control is genuinely usable first',
      );

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<AppFormDropdown<int>>(
              find.byKey(const Key('hod-context-dropdown-section')),
            )
            .enabled,
        isFalse,
        reason: 'the context must not change under an in-flight request',
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('hod-export-pack')))
            .onPressed,
        isNull,
        reason: 'the pack button must be inert while it generates',
      );

      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppFormDropdown<int>>(
              find.byKey(const Key('hod-context-dropdown-section')),
            )
            .enabled,
        isTrue,
        reason: 'a lock that outlived the export would freeze the screen',
      );
    });

    testWidgets('success confirms the downloaded file', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pumpAndSettle();

      expect(find.textContaining('context-pack.xlsx'), findsOneWidget,
          reason: 'the confirmation must name the file that actually landed');
    });

    testWidgets('a 403 fails loudly and offers no false success',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository()
        ..nextError = const ApiException.forbidden();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pumpAndSettle();

      expect(find.text('You are not authorized to access this report.'),
          findsOneWidget);
      expect(find.textContaining('context-pack.xlsx'), findsNothing);
    });

    testWidgets('a 400 keeps the backend contract message', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository()
        ..nextError = const ApiException.badRequest(
            'Select Academic Session, Program, Semester and Section to view the '
            'Attendance Matrix.');
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Select Academic Session'), findsOneWidget,
          reason: 'the actionable server contract must reach the reader');
    });
  });

  group('the pack does not distort Phase 4A', () {
    testWidgets('it is not offered inside HodExportBar', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      // The Phase 4A bar is frozen at exactly two formats of the selected
      // report. The pack is a separate deliverable, not a third format, so the
      // bar's own subtree must contain no pack control.
      final bar = find.byType(HodExportBar);
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byKey(const Key('hod-export-pack'))),
        findsNothing,
        reason: 'adding a pack button to the bar would break the frozen control',
      );
    });

    testWidgets('the per-report export still works alongside it', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-excel')));
      await tester.pumpAndSettle();

      expect(repository.calls.single.method, 'overview',
          reason: 'the pack must not have displaced the report export');
    });

    testWidgets('it creates no extra request of its own', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      final readsBefore = repository.overviewCalls;
      // Merely offering the button must not fetch anything: the preview is
      // still the panel's own loaded data.
      expect(find.byKey(const Key('hod-export-pack')), findsOneWidget);
      expect(repository.overviewCalls, readsBefore);
    });
  });
}