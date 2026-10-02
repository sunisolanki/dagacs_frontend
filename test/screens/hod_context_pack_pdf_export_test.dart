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
import 'package:dagacs_frontend/widgets/hod/hod_export_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One export attempt, recorded with the format it was made for.
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

/// A fully-resolved context whose levels also carry options.
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

/// The five reports the backend builds, in pack order.
const _expectedSections = [
  'Executive Summary',
  'Attendance Matrix',
  'Low Attendance',
  'Subject Summary',
  'Student Summary',
];

void main() {
  group('Phase 4C.3: the Context Pack PDF control', () {
    testWidgets('the hub offers a PDF pack beside the workbook pack',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-export-pack')), findsOneWidget,
          reason: 'the 4B workbook control must survive');
      expect(find.byKey(const Key('hod-export-pack-pdf')), findsOneWidget,
          reason: '4C.3 adds the PDF deliverable as its own control');
      expect(find.text('Context Pack'), findsOneWidget);
      expect(find.text('Context Pack PDF'), findsOneWidget);
    });

    testWidgets('each control states the format it actually produces',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message ?? '')
          .toList();
      // Both tooltips must name the five sections, and must say which file they
      // are about - a control that advertises a file it does not produce is the
      // exact defect the export control exists to prevent.
      expect(tooltips, anyElement(contains('One workbook with')));
      expect(tooltips, anyElement(contains('One PDF with')));
      for (final section in _expectedSections) {
        expect(
            tooltips.where((t) => t.contains(section)).length,
            greaterThanOrEqualTo(2),
            reason: 'both pack controls must list the $section section');
      }
    });

    testWidgets('the PDF control dispatches the pdf format to the pack endpoint',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack-pdf')));
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(1));
      expect(repository.calls.single.method, 'context-pack');
      expect(repository.calls.single.format, 'pdf',
          reason: 'the format is the path segment the backend serves');
    });

    testWidgets('the XLSX control still dispatches xlsx', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack')));
      await tester.pumpAndSettle();

      expect(repository.calls.single.method, 'context-pack');
      expect(repository.calls.single.format, 'xlsx',
          reason: 'adding the PDF must not move the workbook onto a new route');
    });

    testWidgets('the PDF pack carries the context the report was loaded for',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack-pdf')));
      await tester.pumpAndSettle();

      final call = repository.calls.single;
      expect(call.format, 'pdf');
      expect(call.academicSessionId, 1);
      expect(call.programId, 2);
      expect(call.semesterId, 3);
      expect(call.sectionId, 4);
    });

    testWidgets('a context the panel has not reloaded for is never packed as PDF',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      final context = _fullContext();
      await tester.pumpWidget(_hub(repository, academicContext: context));
      await tester.pumpAndSettle();

      // The model moves on but the panel has not refetched, so the screen still
      // shows section A. The PDF must therefore still describe section A.
      context.select(HodContextLevel.section, 9, name: 'B');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack-pdf')));
      await tester.pumpAndSettle();

      expect(repository.calls.single.sectionId, 4,
          reason: 'the file must match the report actually on screen');
    });

    testWidgets('an incomplete context refuses the PDF pack and issues no request',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(
          _hub(repository, academicContext: _sessionOnlyContext()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('report-type-context-overview')));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('hod-export-pack-pdf')));
      expect(button.onPressed, isNull,
          reason: 'a pack contains a cross-tab and needs all four levels');
      expect(repository.calls, isEmpty,
          reason: 'a mixed-context pack must never be requested');
    });

    testWidgets('a double tap on the PDF control issues exactly one request',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository()..gate = Completer<void>();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack-pdf')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hod-export-pack-pdf')),
          warnIfMissed: false);
      await tester.pump();

      expect(repository.calls, hasLength(1),
          reason: 'a second click must not start a second generation');

      repository.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the academic context is locked while the PDF pack generates',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository()..gate = Completer<void>();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack-pdf')));
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
      // Both pack controls go inert together: neither may be offered where the
      // other is refused.
      for (final key in const ['hod-export-pack', 'hod-export-pack-pdf']) {
        expect(
          tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNull,
          reason: '$key must be inert while the pack generates',
        );
      }

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

    testWidgets('success confirms the downloaded PDF file', (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack-pdf')));
      await tester.pumpAndSettle();

      expect(find.textContaining('context-pack.pdf'), findsOneWidget,
          reason: 'the confirmation must name the file that actually landed');
    });

    testWidgets('a 403 on the PDF pack fails loudly and offers no false success',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository()
        ..nextError = const ApiException.forbidden();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-pack-pdf')));
      await tester.pumpAndSettle();

      expect(find.text('You are not authorized to access this report.'),
          findsOneWidget);
      expect(find.textContaining('context-pack.pdf'), findsNothing);
    });

    testWidgets('offering the PDF control creates no request of its own',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      final readsBefore = repository.overviewCalls;
      expect(find.byKey(const Key('hod-export-pack-pdf')), findsOneWidget);
      expect(repository.overviewCalls, readsBefore);
    });
  });

  group('Phase 4C.3 does not distort Phase 4A/4B', () {
    testWidgets('neither pack control is offered inside HodExportBar',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      // The Phase 4A bar is frozen at exactly two formats of the selected
      // report. The pack is a separate deliverable, not a third format, so the
      // bar's own subtree must contain no pack control of either format.
      final bar = find.byType(HodExportBar);
      expect(bar, findsOneWidget);
      for (final key in const [
        'hod-export-pack',
        'hod-export-pack-pdf'
      ]) {
        expect(
          find.descendant(of: bar, matching: find.byKey(Key(key))),
          findsNothing,
          reason: 'adding $key to the bar would break the frozen control',
        );
      }
    });

    testWidgets('the bar still offers exactly two formats of the report',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      // `OutlinedButton.icon` builds a private subclass, so byType would miss it.
      final buttons = tester.widgetList<OutlinedButton>(
        find.descendant(
          of: find.byType(HodExportBar),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(buttons, hasLength(2),
          reason: 'the per-report control is frozen at Excel and PDF');
    });

    testWidgets('the per-report export still works alongside both pack controls',
        (tester) async {
      _largeSurface(tester);
      final repository = _RecordingRepository();
      await tester.pumpWidget(_hub(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-export-excel')));
      await tester.pumpAndSettle();

      expect(repository.calls.single.method, 'overview',
          reason: 'the pack must not have displaced the report export');
    });
  });
}
